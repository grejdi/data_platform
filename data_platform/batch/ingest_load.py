
import os
import logging
from dotenv import load_dotenv
import boto3
import json
import argparse

from data_platform.db import dbSession
from data_platform.db.models.prefix import Prefix
from data_platform.db.models.load import Load


def run():
  # initialize boto clients
  stepFunctions = boto3.client('stepfunctions')

  # to keep track of where the load objects will be appended to
  prefixes = {}

  with dbSession() as db:
    # get load records with 'ready' status, ordered by modified, key (just in case)
    loadRecs = db.query(Load, Prefix).join(Prefix, Load.prefix_id == Prefix.id).filter(Load.status == 'ready').order_by(Load.s3_modified, Load.s3_key).all()
    for loadRec, prefixRec in loadRecs:
      if prefixRec.name in prefixes:
        prefixes[prefixRec.name]['load_ids'].append(loadRec.id)
        prefixes[prefixRec.name]['load_s3_keys'].append('s3://{}/{}'.format(os.environ.get('S3_BUCKET_INCOMING'), loadRec.s3_key))
      else:
        prefixes[prefixRec.name] = {
          'name': prefixRec.name,
          's3_prefix': prefixRec.s3_prefix,
          'snapshot': prefixRec.snapshot.isoformat(),

          'load_ids': [ loadRec.id ],
          'load_s3_keys': [ 's3://{}/{}'.format(os.environ.get('S3_BUCKET_INCOMING'), loadRec.s3_key) ]
        }

    # start ingesting
    for prefixName, prefix in prefixes.items():
      # update load records' status to 'ingesting'
      # @todo this is not updating the modified field
      db.query(Load).filter(Load.id.in_(prefix.get('load_ids'))).update({ Load.status: 'ingesting' })
      db.commit()

      # construct input for step function
      stepFunctionInput = {
        'env': json.dumps({
          'GLUE_DATABASE_NAME': os.environ.get('GLUE_DATABASE_NAME'),
          'S3_BUCKET_SPRINGBOARD': os.environ.get('S3_BUCKET_SPRINGBOARD'),
          'S3_BUCKET_SPRINGBOARD_PREFIX': os.environ.get('S3_BUCKET_SPRINGBOARD_PREFIX'),
        }),
        'input': json.dumps({
          'prefixes': [ prefix ]
        })
      }

      try:
        # run step function
        stepFunctions.start_execution(
          stateMachineArn=os.environ.get('INGEST_STEP_FUNCTION_ARN'),
          input=json.dumps(stepFunctionInput)
        )
      # if execution failed to start, update status to 'ingesting_error', and log error
      except (
        stepFunctions.exceptions.ExecutionLimitExceeded,
        stepFunctions.exceptions.ExecutionAlreadyExists,
        stepFunctions.exceptions.InvalidArn,
        stepFunctions.exceptions.InvalidExecutionInput,
        stepFunctions.exceptions.InvalidName,
        stepFunctions.exceptions.StateMachineDoesNotExist,
        stepFunctions.exceptions.StateMachineDeleting
      ) as e:
        db.query(Load).filter(Load.s3_key.in_(prefix.get('load_ids'))).update({ Load.status: 'ingesting_error' })
        db.commit()

        logging.error('[data_platform] [batch] [ingest_load]: {}'.format(e))

if __name__ == '__main__':
  run()



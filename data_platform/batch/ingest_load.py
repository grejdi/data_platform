
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
      prefixes.setdefault(prefixRec.name, []).append(loadRec.s3_key)

    # start ingesting
    for prefixName, loadObjectKeys in prefixes.items():
      # update load records' status to 'ingesting'
      # @todo this is not updating the modified field
      db.query(Load).filter(Load.s3_key.in_(loadObjectKeys)).update({ Load.status: 'ingesting' })
      db.commit()

      try:
        # construct input for step function
        stepFunctionInput = json.dumps({
          'env': {
            'GLUE_DATABASE_NAME': os.environ.get('GLUE_DATABASE_NAME'),
            'S3_BUCKET_SPRINGBOARD': os.environ.get('S3_BUCKET_SPRINGBOARD'),
            'S3_BUCKET_SPRINGBOARD_PREFIX': os.environ.get('S3_BUCKET_SPRINGBOARD_PREFIX'),
          },
          'input': {
            'prefixes': [
              {
                'name': 'sample',
                's3_prefix': 'incoming/SAMPLE',
                'snapshot': '2022-01-09',

                'load_s3_keys': [
                  's3://grejdi.data-platform/incoming/SAMPLE/sample01.csv',
                  's3://grejdi.data-platform/incoming/SAMPLE/sample02.csv'
                ]
              }
            ]
          }
        })

        # run step function
        stepFunctions.start_execution(
          stateMachineArn=os.environ.get('INGEST_STEP_FUNCTION_ARN'),
          input=stepFunctionInput
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
        db.query(Load).filter(Load.s3_key.in_(loadObjectKeys)).update({ Load.status: 'ingesting_error' })
        db.commit()

        logging.error('[data_platform] [batch] [ingest_load]: {}'.format(e))

if __name__ == '__main__':
  run()



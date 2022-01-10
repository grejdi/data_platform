
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
          'prefix_name': prefixName,
          'load_object_keys': loadObjectKeys
        })

        # run step function
        stepFunctions.start_execution(
          stateMachineArn=os.environ.get('INGEST_STEP_FUNCTION_ARN')+'ds',
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
        db.query(Load).filter(Load.s3_key.in_(loadObjectKeys)).update({ Load.status: 'ready' })
        db.commit()

        logging.error('[data_platform] [batch] [ingest_load]: {}'.format(e))

if __name__ == '__main__':
  run()



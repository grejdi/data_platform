
import os
import logging
from dotenv import load_dotenv
import boto3
import json
import argparse

from data_platform.db import dbSession
from data_platform.db.models.prefix import Prefix
from data_platform.db.models.load import Load

# get enviroment variables from .env file
load_dotenv()

# initialize clients
sqs = boto3.client('sqs')
stepFunctions = boto3.client('stepfunctions')

# if we are on local, then make some updates to the clients
if os.environ.get('ENV') == 'local':
  # and if we have specified a boto profile to use, then override clients to use the specific session
  if os.environ.get('BOTO_PROFILE'):
    botoSession = boto3.Session(profile_name=os.environ.get('BOTO_PROFILE'))
    sqs = botoSession.client('sqs')
    stepFunctions = botoSession.client('stepfunctions')

def getIncomingMessages(availablePrefixes=[], dryRun=True):
    # ping SQS for messages
    response = sqs.receive_message(
      QueueUrl=os.environ.get('INCOMING_QUEUE_URL'),
      MaxNumberOfMessages=10, # get up to 10 messages at a time
      WaitTimeSeconds=2 # tell sqs to wait up to 2 seconds before returning without messages
    )

    messages = response.get('Messages', [])
    if messages:
      logging.error('Received messages #: {}'.format(len(messages)))

      # loop through messages received
      for message in messages:
        # make sure we have a receipt handler so we can remove message from queue, otherwise skip
        # note: this shouldn't happen
        receiptHandle = message.get('ReceiptHandle')
        if not receiptHandle:
          logging.info('-- Skipped - Missing Message Receipt Handle (Message: {})'.format(message))
          # skip message
          continue

        # process message body from EventBridge, by loading it into a dict
        bodyDict = json.loads(message.get('Body', '{}'))
        if bodyDict:
          loadS3Key = bodyDict.get('detail', {}).get('requestParameters', {}).get('key')

          # determine which prefix the load is for
          for prefixRec in availablePrefixes:
            if loadS3Key.startswith('{}/'.format(prefixRec.s3_prefix)):
              if not dryRun:
                with dbSession() as db:
                  loadRec = Load(**{
                    'prefix_id': prefixRec.id,
                    's3_key': loadS3Key,
                    'status': 'ready'
                  })
                  db.add(loadRec)
                  db.commit()
              else:
                logging.error('Insert Into "Load" Table: {}'.format(json.dumps({
                  'prefix_id': prefixRec.id,
                  's3_key': loadS3Key,
                  'status': 'ready'
                })))

              # we found the prefix and inserted the record, so stop 
              break


        if not dryRun:
          # delete queue message as we will use the database to continue processing
          response = sqs.delete_message(
            QueueUrl=os.environ.get('INCOMING_QUEUE_URL'),
            ReceiptHandle=receiptHandle
          )

      # recursively get more messages
      getIncomingMessages(availablePrefixes=availablePrefixes, dryRun=dryRun)

def startIngestWorkflows(dryRun=True):
  kot = {}
  with dbSession() as db:
    # get all load records in 'ready' status
    loadRecs = db.query(Load, Prefix).join(Prefix, Load.prefix_id == Prefix.id).filter(Load.status == 'ready').order_by(Load.s3_key).all()

    for loadRec, prefixRec in loadRecs:
      kot.setdefault(prefixRec.s3_prefix, []).append(loadRec.s3_key)

  # start ingest step function per prefix
  for key, val in kot.items():
    # construct input for step function
    stepFunctionInput = json.dumps({
      'prefix': key,
      'loadObjectKeys': val
    })
    if not dryRun:
      stepFunctions.start_execution(
        stateMachineArn=os.environ.get('INGEST_STEP_FUNCTION_ARN'),
        input=stepFunctionInput
      )
    else:
      logging.error('Start Execution of Step Function ({}): {}'.format(
        os.environ.get('INGEST_STEP_FUNCTION_ARN'),
        stepFunctionInput
      ))

if __name__ == '__main__':

  parser = argparse.ArgumentParser()
  parser.add_argument(
    '--run',
    action='store_const',
    const=True,
    default=False
  )
  args = parser.parse_args()

  # get prefixes currently allowed in data platform
  prefixRecs = []
  with dbSession() as db:
    prefixRecs = db.query(Prefix).all() # @todo filter deleted

  # 
  getIncomingMessages(availablePrefixes=prefixRecs, dryRun=not args.run)
  startIngestWorkflows(dryRun=not args.run)



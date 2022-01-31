
import os
import logging
import datetime
from dotenv import load_dotenv
import boto3
import json
import argparse

from data_platform.db import dbSession
from data_platform.db.models.table import Table
from data_platform.db.models.load import Load


# get enviroment variables from .env file, if not already set
load_dotenv()

def startStepFunctionExecution(botoClient, db, tables):
  # get load ids we are updating
  loadIds = []
  for table in tables:
    loadIds += table.get('load_id', [])

  try:
    # if on local environment, provide commands for workflow
    if os.environ.get('ENV') == 'local':
      logging.info('@todo')
    else:
      # run step function
      # botoClient.start_execution(
      #   stateMachineArn=os.environ.get('STEP_FUNCTION_INGEST_ARN'),
      #   input=json.dumps({
      #     'env': json.dumps({
      #       'GLUE_DATABASE_NAME': os.environ.get('GLUE_DATABASE_NAME'),
      #       'S3_BUCKET': os.environ.get('S3_BUCKET')
      #     }),
      #     'input': json.dumps({
      #       'tables': tables
      #     })
      #   })
      # )
      logging.error(json.dumps({
        'env': json.dumps({
          'GLUE_DATABASE_NAME': os.environ.get('GLUE_DATABASE_NAME'),
          'S3_BUCKET': os.environ.get('S3_BUCKET')
        }),
        'input': json.dumps({
          'tables': tables
        })
      }))

    # update load records' status to 'ingesting'
    # note: setting modified explicitly since before_update in base.py doesn't run. @todo why?
    db.query(Load).filter(Load.id.in_(loadIds)).update({
      Load.status: 'ingesting',
      Load.modified: datetime.datetime.utcnow()
    })
    # commit 'ingesting' status update
    db.commit()

  # if execution failed to start, update status to 'ingesting_error' for the tables, and log error
  except (
    botoClient.exceptions.ExecutionLimitExceeded,
    botoClient.exceptions.ExecutionAlreadyExists,
    botoClient.exceptions.InvalidArn,
    botoClient.exceptions.InvalidExecutionInput,
    botoClient.exceptions.InvalidName,
    botoClient.exceptions.StateMachineDoesNotExist,
    botoClient.exceptions.StateMachineDeleting
  ) as e:
    # note: setting modified explicitly since before_update in base.py doesn't run. @todo why?
    db.query(Load).filter(Load.s3_key.in_(loadIds)).update({
      Load.status: 'ingesting_error',
      Load.modified: datetime.datetime.utcnow()
    })
    # commit 'ingesting_error' status update
    db.commit()

    logging.error('{}: {}'.format(logPrefix, e))

def run():
  # initialize boto clients
  stepFunctionsClient = boto3.client('stepfunctions')

  # helpful variables
  # log prefix, for identifying logs
  logPrefix = '[data_platform] [batch] [ingest_load]'
  # data limit (in bytes), how many bytes allowed per execution
  byteLimit = 100000000 # 100MB
  # to keep track of where the load objects will be appended into
  tables = []
  # number of allowed executions. this number should align with the
  # concurrency value of the glue job.
  executionLimit = 10

  # get number of step function execution currently running, so we can adjust limit
  if os.environ.get('ENV') == 'local':
    logging.info('{}: No limitations on local.'.format(logPrefix))
  else:
    try:
      listExecutionsResponse = stepFunctionsClient.list_executions(
        stateMachineArn=os.environ.get('STEP_FUNCTION_INGEST_ARN'),
        statusFilter='RUNNING',
        # use execution limit
        maxResults=executionLimit # max allowed is 1000
      )
      # @todo remove logging 
      logging.error(listExecutionsResponse)

      # adjust execution limit based on the number currently running
      executionLimit = executionLimit - len(listExecutionsResponse.get('executions', []))
    except (
      stepFunctionsClient.exceptions.InvalidArn,
      stepFunctionsClient.exceptions.InvalidToken,
      stepFunctionsClient.exceptions.StateMachineDoesNotExist,
      stepFunctionsClient.exceptions.StateMachineTypeNotSupported
    ) as e:
      logging.error('{}: {}'.format(logPrefix, e))

  with dbSession() as db:
    # get load records with 'ready' status, ordered by modified, key (just in case)
    loadRecs = db.query(Load, Table)\
                 .join(Table, Load.table_id == Table.id)\
                 .filter(Load.status == 'ready')\
                 .order_by(Load.s3_modified, Load.s3_key)\
                 .all()

    # put them into a structure that makes sense as a step function input
    for loadRec, tableRec in loadRecs:
      tables.append({
        'name': tableRec.name,
        's3_prefix': tableRec.s3_prefix,
        'snapshot': tableRec.snapshot.strftime("%Y%m%d%H%M%S"),

        'load_id': loadRec.id,
        'load_s3_key': loadRec.s3_key,
        'load_size': loadRec.s3_size,
        'load_is_cdc': loadRec.is_cdc
      })

    # start ingesting workflow
    executionCount = 0
    byteCount = 0
    stepFunctionInputTables = []
    for table in tables:
      # update byte count
      byteCount += table.get('load_size', 0)

      # add to the step function input
      stepFunctionInputTables.append(table)

      # if we have reached the byte limit, then start an execution
      if byteCount >= byteLimit:
        # start execution only if we haven't reached the limit
        if executionCount <= executionLimit:
          startStepFunctionExecution(stepFunctionsClient, db, stepFunctionInputTables)

          # add to execution count to allow for comparing to limit
          executionCount += 1

          # reset
          byteCount = 0
          stepFunctionInputTables = []

    # if there are leftover tables to be ingested, start one last execution
    if stepFunctionInputTables:
      # start execution only if we haven't reached the limit
      if executionCount <= executionLimit:
        startStepFunctionExecution(stepFunctionsClient, db, stepFunctionInputTables)


if __name__ == '__main__':
  run()

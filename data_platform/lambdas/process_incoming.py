
import os
import boto3
import botocore
import logging

from data_platform.db import dbSession
from data_platform.db.models.table import Table
from data_platform.db.models.load import Load


def run(loadKey):

  # intialize boto clients
  s3 = boto3.client('s3')

  # get s3 info for load
  try:
    loadS3Info = s3.head_object(
      Bucket=os.environ.get('S3_BUCKET_INCOMING'),
      Key=loadKey
    )
  # if any exception, return with error
  except botocore.exceptions.ClientError as e:
    logging.error('[data_platform] [lambdas] [process_incoming]: {}'.format(e))
    return {
      'type': 'error',
      'message': e
    }

  # start a db session to use with updating database
  with dbSession() as db:
    # get all tables that are not deleted
    tableRecs = db.query(Table).filter(Table.deleted is not None).all()

    # determine which table the load is for
    tableAvailable = False
    # determine is the load is CDC (Change Data Capture)
    isCDCLoad = False
    for tableRec in tableRecs:
      # check if it's regular load file
      if loadKey.startswith('incoming/{}'.format(tableRec.s3_prefix)):
        isTableAvailable = True

      # check if it's a cdc load file (prefix ends with '__ct')
      if loadKey.startswith('incoming/{}cdc/'.format(tableRec.s3_prefix)):
        isTableAvailable = True
        isCDCLoad = True

      # if we have found a table record that we can associate the load with, then add the load record
      if isTableAvailable:
        # if we are trying to insert a load that matches the snapshot key, we should update the snapshot
        # value for the table
        if loadKey == 'incoming/{}'.format(tableRec.snapshot_s3_key):
          tableRec.snapshot = loadS3Info.get('LastModified')

        # insert a load record
        loadRec = Load(**{
          'table_id': tableRec.id,
          'status': 'ready',
          'snapshot': tableRec.snapshot,
          'is_cdc': isCDCLoad,
          's3_key': loadKey,
          's3_modified': loadS3Info.get('LastModified'),
          's3_size': loadS3Info.get('Size'),
        })
        db.add(loadRec)

        # commit load record insert, and any update to the table snapshot
        db.commit()

        # we found the table and inserted the record, so stop
        break

    # if we didn't find the table, let others know by logging an error
    if not isTableAvailable:
      errorMessage = 'Table doesn\'t exist for the load object: {}'.format(loadKey)

      logging.error('[data_platform] [lambdas] [process_incoming]: {}'.format(errorMessage))
      return {
        'type': 'error',
        'message': errorMessage
      }

  return {
    'type': 'success'
  }

if __name__ == '__main__':
  run()

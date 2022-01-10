
import os
import boto3
import botocore
import logging

from data_platform.db import dbSession
from data_platform.db.models.prefix import Prefix
from data_platform.db.models.load import Load


def run(loadS3Key):

  # intialize boto clients
  s3 = boto3.client('s3')

  logging.error('HERE')

  # get s3 info for load
  try:
    loadS3Info = s3.head_object(
      Bucket=os.environ.get('S3_BUCKET_INCOMING'),
      Key=loadS3Key
    )
  # if any exception, return with error
  except botocore.exceptions.ClientError as e:
    logging.error('[data_platform] [lambda] [process_incoming]: {}'.format(e))
    return {
      'type': 'error',
      'message': e
    }

  # start a db session to use with updating database
  with dbSession() as db:
    # get all prefixes that are not deleted
    prefixRecs = db.query(Prefix).filter(Prefix.deleted is not None).all()

    # determine which prefix the load is for
    prefixAvailable = False
    for prefixRec in prefixRecs:
      if loadS3Key.startswith('{}{}/'.format(os.environ.get('S3_BUCKET_INCOMING_PREFIX'), prefixRec.s3_prefix)):
        prefixAvailable = True

        # if we are trying to insert a snapshot key, we should update the snapshot
        # value for the prefix
        if loadS3Key == '{}{}'.format(os.environ.get('S3_BUCKET_INCOMING_PREFIX'), prefixRec.snapshot_s3_key):
          prefixRec.snapshot = loadS3Info.get('LastModified') 

        # insert a load record
        loadRec = Load(**{
          'prefix_id': prefixRec.id,
          'status': 'ready',
          'snapshot': prefixRec.snapshot,
          's3_key': loadS3Key,
          's3_modified': loadS3Info.get('LastModified'),
        })
        db.add(loadRec)

        db.commit()

        # we found the prefix and inserted the record, so stop 
        break

    # if we didn't find the prefix, let others know by logging an error
    if not prefixAvailable:
      errorMessage = 'Prefix doesn\'t exist for Load: {}'.format(loadS3Key)

      logging.error('[data_platform] [lambda] [process_incoming]: {}'.format(errorMessage))
      return {
        'type': 'error',
        'message': errorMessage
      }

  return {
    'type': 'success'
  }

if __name__ == '__main__':
  run()

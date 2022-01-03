
import boto3
import logging
import json

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

## @params: [JOB_NAME, OBJECT_KEY]
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'OBJECT_KEY'])

# test out logging
print('PRINT')
logging.debug('DEBUG')
logging.info('INFO')
logging.warning('WARNING')
logging.error('ERROR')
logging.critical('CRITICAL')

logging.error('--------------------------------------------------------')
logging.error(str(sys.argv))
logging.error(json.dumps(args))
logging.error('--------------------------------------------------------')

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

logging.error('GLUE HERE: {}'.format(args.get('OBJECT_KEY', 'OBJECT NOT FOUND')))

job.commit()

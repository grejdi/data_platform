
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

logging.info('--------------------------------------------------------')
logging.info(str(sys.argv))
logging.info(json.dumps(args))
logging.info('--------------------------------------------------------')

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

logging.info('GLUE HERE: {}'.format(args.get('OBJECT_KEY', 'OBJECT NOT FOUND')))

job.commit()

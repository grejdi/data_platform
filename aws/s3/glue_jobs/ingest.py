
from awsglue.dynamicframe import DynamicFrame
import logging
import json
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *


sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'INPUT'])

# create job using the glue context
job = Job(glueContext)
# initialize job, with a default name 'ingest'
job.init(args.get('JOB_NAME', 'ingest'), args)

# read input
inputDict = json.loads(args.get('INPUT', '{}'))

inputDict = {
  'env': {
    'GLUE_DATABASE_NAME': 'data_platform',
    'S3_BUCKET_SPRINGBOARD': 'grejdi.data-platform',
    'S3_BUCKET_SPRINGBOARD_PREFIX': 'output/',
  },
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

# run glue transformations for each prefix
for prefix in inputDict.get('prefixes', []):

  # read prefix using the data catalog in glue
  prefixDF = glueContext.create_dynamic_frame.from_catalog(
    database=inputDict.get('env', {}).get('GLUE_DATABASE_NAME'),
    table_name='incoming__{}'.format(prefix.get('name')),
    additional_options={
      'paths': prefix.get('load_s3_keys')
    },
    transformation_ctx="ingest_prefix_df_read"
  )
  newDF = prefixDF.toDF()
  newDF = newDF.withColumn("snapshot", lit(prefix.get('snapshot')))
  prefixDF = DynamicFrame.fromDF(newDF, glueContext, "prefixDF")

  glueContext.write_dynamic_frame.from_options(
    frame=prefixDF,
    connection_type='s3',
    format='glueparquet',
    connection_options={
      'path': 's3://{}/{}{}.parquet/'.format(
        inputDict.get('env', {}).get('S3_BUCKET_SPRINGBOARD'),
        inputDict.get('env', {}).get('S3_BUCKET_SPRINGBOARD_PREFIX'),
        prefix.get('s3_prefix')
      ),
      'partitionKeys': ['snapshot']
    },
    format_options={ 'compression': 'gzip' },
    transformation_ctx='ingest_prefix_df_write_parquet',
  )  

job.commit()

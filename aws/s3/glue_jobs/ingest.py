
import logging
import json
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import *


sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'ENV', 'INPUT'])

# create job using the glue context
job = Job(glueContext)
# initialize job, with a default name 'ingest'
job.init(args.get('JOB_NAME', 'ingest'), args)

# read env and input
envDict = json.loads(args.get('ENV', '{}'))
inputDict = json.loads(args.get('INPUT', '{}'))

# run glue transformations for each prefix
for prefix in inputDict.get('prefixes', []):

  # read prefix using the data catalog in glue
  prefixDF = glueContext.create_dynamic_frame.from_catalog(
    database=envDict.get('GLUE_DATABASE_NAME'),
    table_name='incoming__{}'.format(prefix.get('name')),
    additional_options={
      'paths': prefix.get('load_s3_keys')
    },
    transformation_ctx="ingest_prefix_df_read"
  )
  # convert to spark dataframe so we can use withColum
  prefixSparkDF = prefixDF.toDF()
  # add a new column for snapshot and set to the value of the prefix's snapshot
  prefixSparkDF = prefixSparkDF.withColumn("snapshot", lit(prefix.get('snapshot')))
  # convert back to glue's dynamic frame
  prefixDF = DynamicFrame.fromDF(prefixSparkDF, glueContext, "prefixDF")

  glueContext.write_dynamic_frame.from_options(
    frame=prefixDF,
    connection_type='s3',
    format='glueparquet',
    connection_options={
      'path': 's3://{}/{}{}.parquet/'.format(
        envDict.get('S3_BUCKET'),
        prefix.get('s3_prefix')
      ),
      'partitionKeys': ['snapshot']
    },
    format_options={ 'compression': 'gzip' },
    transformation_ctx='ingest_prefix_df_write_parquet',
  )  

job.commit()

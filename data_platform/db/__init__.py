
import boto3
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

# import tables to put them in scope and allow alembic to autogenerate any changes
from data_platform.db.models import (
  incoming
)


# get enviroment variables from .env file
load_dotenv()

# helper variables for interacting with database
dbHost = os.environ.get('DB_HOST')
dbPort = os.environ.get('DB_PORT', '5432')
dbUser = os.environ.get('DB_USER')
dbPassword = os.environ.get('DB_PASSWORD')
dbSSL = {} # no config initially
dbName = os.environ.get('DB_NAME')
# connection url to database
dbURL = ''

connectArgs = {}
# if we are on local, then make some updates
if os.environ.get('ENV') == 'local':
  # a couple of options for local based on whether user/password is set or not
  if dbUser and dbPassword:
    connectArgs = {
      'host': dbHost,
      'user': dbUser,
      'password': dbPassword,
      'dbname': dbName
    }
  else:
    connectArgs = {
      'host': dbHost,
      'dbname': dbName
    }

# otherwise running on RDS
else:
  # initialize clients
  rds = boto3.client('rds')

  # generate IAM-auth password
  dbPassword = rds.generate_db_auth_token(
    DBHostname='dataplatform.proxy-ccnlslbcr8ut.us-east-1.rds.amazonaws.com',
    Port=dbPort,
    DBUsername=dbUser
  )

  connectArgs = {
    'host': 'dataplatform.proxy-ccnlslbcr8ut.us-east-1.rds.amazonaws.com',
    'user': dbUser,
    'password': dbPassword,
    'dbname': dbName,
    'sslmode': 'verify-full',
    'sslrootcert': '/data_platform/data_platform/db/certs/AmazonRootCA1.pem',
  }

  # dbURL = 'postgresql+psycopg2://{}:{}@{}/{}?sslmode=verify-full'.format(dbUser, dbPassword.replace('%', '%%'), 'dataplatform.proxy-ccnlslbcr8ut.us-east-1.rds.amazonaws.com', dbName)

# create connection
dbEngine = create_engine('postgresql+psycopg2://', connect_args=connectArgs)

# database session maker
dbSession = sessionmaker(dbEngine)

# wget https://s3.amazonaws.com/rds-downloads/rds-ca-2019-root.pem
# export RDSHOST="dataplatform.ccnlslbcr8ut.us-east-1.rds.amazonaws.com"
# export PG_USER="iamuser"
# export PGPASSWORD="$(aws rds generate-db-auth-token --hostname $RDSHOST --port 5432 --region us-east-1 --username $PG_USER )"
# psql "host=$RDSHOST port=5432 sslmode=verify-full sslrootcert=rds-ca-2019-root.pem dbname=dataplatform user=$PG_USER"

# wget https://www.amazontrust.com/repository/AmazonRootCA1.pem
# export RDSHOST="dataplatform.proxy-ccnlslbcr8ut.us-east-1.rds.amazonaws.com"
# export PG_USER="postgres"
# export PGPASSWORD="$(aws rds generate-db-auth-token --hostname $RDSHOST --port 5432 --region us-east-1 --username $PG_USER )"
# psql "host=$RDSHOST port=5432 sslmode=verify-full sslrootcert=AmazonRootCA1.pem dbname=dataplatform user=$PG_USER"

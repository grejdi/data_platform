
from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import INTEGER, TIMESTAMP, VARCHAR, DATE

from data_platform.db.models.base import Base



# create table metadata__tables (
#   id bigint,
#   name varchar, @todo maybe make unique
#   modified_field varchar,
#   partition_field varchar,
# )



class Incoming(Base):

  __tablename__ = 'incoming'

  name = Column(VARCHAR(500), nullable=False)
  s3_prefix = Column(VARCHAR(1000), nullable=False)
  partition = Column(VARCHAR(1000), nullable=False)

def get():
  pass
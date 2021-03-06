
from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import INTEGER, TIMESTAMP, VARCHAR, DATE, BOOLEAN, BIGINT

from data_platform.db.models.base import Base


class Load(Base):

  __tablename__ = 'loads'

  table_id = Column(INTEGER, nullable=False)
  status = Column(VARCHAR(100), nullable=False)
  snapshot = Column(TIMESTAMP, nullable=False)
  is_cdc = Column(BOOLEAN, nullable=False)

  s3_key = Column(VARCHAR(1000), nullable=False)
  s3_modified = Column(TIMESTAMP, nullable=False)
  s3_size = Column(BIGINT, nullable=False)

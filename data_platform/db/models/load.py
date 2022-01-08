
from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import INTEGER, TIMESTAMP, VARCHAR, DATE

from data_platform.db.models.base import Base


class Load(Base):

  __tablename__ = 'load'

  prefix_id = Column(INTEGER, nullable=False)

  s3_key = Column(VARCHAR(1000), nullable=False)
  status = Column(VARCHAR(100), nullable=False)


from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import INTEGER, TIMESTAMP, VARCHAR, DATE

from data_platform.db.models.base import Base


class Load(Base):

  __tablename__ = 'loads'

  prefix_id = Column(INTEGER, nullable=False)
  status = Column(VARCHAR(100), nullable=False)
  snapshot = Column(TIMESTAMP, nullable=False)

  s3_key = Column(VARCHAR(1000), nullable=False)
  s3_modified = Column(TIMESTAMP, nullable=False)
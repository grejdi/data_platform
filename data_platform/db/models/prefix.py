
from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import INTEGER, TIMESTAMP, VARCHAR, DATE

from data_platform.db.models.base import Base


class Prefix(Base):

  __tablename__ = 'prefixes'

  name = Column(VARCHAR(500), nullable=False)
  snapshot = Column(TIMESTAMP, nullable=False)
  snapshot_s3_key = Column(VARCHAR(1000), nullable=False)

  s3_prefix = Column(VARCHAR(1000), nullable=False)

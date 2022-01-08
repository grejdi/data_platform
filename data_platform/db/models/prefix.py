
from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import INTEGER, TIMESTAMP, VARCHAR, DATE

from data_platform.db.models.base import Base


class Prefix(Base):

  __tablename__ = 'prefix'

  name = Column(VARCHAR(500), nullable=False)
  s3_prefix = Column(VARCHAR(1000), nullable=False)
  partition = Column(VARCHAR(1000), nullable=False)


import logging
from logging_tree import printout
from logging_tree.format import build_description

from data_platform.db import dbSession
from data_platform.db.models.prefix import Prefix
from data_platform.db.models.load import Load


def run():
  logging.error('LAMBDA:: PROCESS INCOMING')
  logging.error(build_description())

  with dbSession() as db:
    # get all load records in 'ready' status
    loadRecs = db.query(Load, Prefix).join(Prefix, Load.prefix_id == Prefix.id).filter(Load.status == 'ready').order_by(Load.s3_key).all()


if __name__ == '__main__':
  run()

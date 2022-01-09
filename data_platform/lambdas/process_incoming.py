
import logging
from logging_tree import printout
from logging_tree.format import build_description


def run():
  logging.error('LAMBDA:: PROCESS INCOMING')
  logging.error(build_description())


if __name__ == '__main__':
  run()

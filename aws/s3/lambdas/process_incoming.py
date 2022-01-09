
import json
import logging

from data_platform.lambdas import process_incoming


def run(event, context):
  logging.error(json.dumps(event))
  logging.error('LAMBDA')
  process_incoming.run()

  return {}

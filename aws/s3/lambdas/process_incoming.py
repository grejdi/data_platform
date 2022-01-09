
import logging

import data_platform.lambdas.process_incoming

def run(event, context):

  logging.error('LAMBDA')

  process_incoming.run()

  return {}

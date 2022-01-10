
import json
import logging

from data_platform.lambdas import process_ingestion


def run(event, context):
  return process_ingestion.run()

if __name__ == '__main__':
  # test
  run({}, {})
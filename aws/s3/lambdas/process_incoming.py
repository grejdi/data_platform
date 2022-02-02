
import json
import logging

from data_platform.lambdas import process_incoming


def run(event, context):
  logging.error(json.dumps(event))
  return process_incoming.run(event.get('detail', {}).get('requestParameters', {}).get('key'))

if __name__ == '__main__':
  # test
  run({
    'detail': {
      'requestParameters': {
        'key': 'incoming/SAMPLE/sample02.csv'
      }
    }
  }, {})
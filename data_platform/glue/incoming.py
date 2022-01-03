
import logging
from logging_tree import printout
from logging_tree.format import build_description

def main():
  logging.error('GLUE PACKAGE HERE!')
  logging.error(build_description())

if __name__ == '__main__':
  main()

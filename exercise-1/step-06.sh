#!/usr/bin/bash -x
echo "Table tests:"
sqlite3 \
  -cmd '.mode column' \
  -cmd '.headers on' \
  results.sqlite \
  "select compiler, optl, switches, comparison, nanosec from tests;"

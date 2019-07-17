#!/usr/bin/bash
echo "Tables in results.sqlite:"
sqlite3 results.sqlite ".tables"

echo
echo "Table runs:"
sqlite3 \
  -cmd '.mode column' \
  -cmd '.headers on' \
  results.sqlite "select * from runs;"

#!/bin/bash -x
echo "Tables in results.sqlite:"
sqlite3 results.sqlite ".tables"

echo -e "\nTable runs:"
sqlite3 \
  -cmd '.mode column' \
  -cmd '.headers on' \
  results.sqlite "select * from runs;"

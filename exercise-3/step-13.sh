#!/bin/bash -x
flit bisect \
  --auto-sqlite-run ./results.sqlite \
  --parallel 1 \
  --jobs 1

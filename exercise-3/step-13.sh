#!/usr/bin/bash
flit bisect \
  --auto-sqlite-run ./results.sqlite \
  --parallel 1 \
  --jobs 1

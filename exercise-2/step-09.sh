#!/bin/bash -x
flit bisect \
  --precision=double \
  "g++-7 -O3 -mfma" \
  Mfem13

#!/usr/bin/bash
flit bisect \
  --precision=double \
  "g++-7 -O3 -mfma" \
  Mfem13

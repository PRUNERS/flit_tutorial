#!/usr/bin/bash
flit bisect \
  --biggest=1 \
  --precision=double \
  "g++-7 -O3 -funsafe-math-optimizations" \
  LuleshTest

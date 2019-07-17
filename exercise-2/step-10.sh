#!/usr/bin/bash -x
cat -n ../packages/mfem/linalg/densemat.cpp 2>/dev/null | \
  tail -n +3680 | \
  head -n 40

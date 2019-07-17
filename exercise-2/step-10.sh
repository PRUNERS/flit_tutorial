#!/bin/bash -x
pygmentize ../packages/mfem/linalg/densemat.cpp 2>/dev/null | \
  cat -n | \
  tail -n +3680 | \
  head -n 40

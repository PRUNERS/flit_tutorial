#!/usr/bin/bash -x
diff -u ../exercise-1/custom.mk ./custom.mk | \
  pygmentize

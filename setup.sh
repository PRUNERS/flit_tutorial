#!/bin/bash

pushd hypre-2.10.0b/src
./configure --disable-fortran
make
popd

pushd metis
make
popd

pushd mfem
make config MFEM_USE_MPI=YES
popd



#!/bin/bash

set -e
set -u

mkdir -p packages
pushd packages

export MAKEFLAGS=-j8
export HYPRE_VERSION=2.11.2
export METIS_VERSION=4.0.3
export MFEM_VERSION=3.4
# export GLVIS_VERSION=3.4

# clone and build hypre
wget https://github.com/hypre-space/hypre/archive/v${HYPRE_VERSION}.tar.gz
tar -xzf v${HYPRE_VERSION}.tar.gz
rm v${HYPRE_VERSION}.tar.gz
ln -s hypre-${HYPRE_VERSION} hypre
ln -s hypre-${HYPRE_VERSION} hypre-2.10.0b
pushd hypre/src
./configure --disable-fortran
make
popd

# clone and build metis
wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/OLD/metis-${METIS_VERSION}.tar.gz
tar -xzf metis-${METIS_VERSION}.tar.gz
make --directory metis-${METIS_VERSION}
ln -s metis-${METIS_VERSION} metis
ln -s metis-${METIS_VERSION} metis-4.0
rm metis-${METIS_VERSION}.tar.gz

# clone and build mfem
wget https://github.com/mfem/mfem/archive/v${MFEM_VERSION}.tar.gz
tar -xzf v${MFEM_VERSION}.tar.gz
rm v${MFEM_VERSION}.tar.gz
ln -s mfem-${MFEM_VERSION} mfem
make config MFEM_USE_MPI=YES --directory mfem-${MFEM_VERSION}
make --directory mfem-${MFEM_VERSION}

## # clone and build glvis
## wget http://glvis.github.io/releases/glvis-${GLVIS_VERSION}.tgz
## tar -xzf glvis-${GLVIS_VERSION}.tgz
## rm glvis-${GLVIS_VERSION}.tgz
## make clean --directory glvis-${GLVIS_VERSION}
## make MFEM_DIR=../mfem-${MFEM_VERSION} --directory glvis-${GLVIS_VERSION}

# clone LULESH
git clone https://github.com/LLNL/LULESH.git

# out of packages
popd

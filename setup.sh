#!/bin/bash

set -e
set -u

export MAKEFLAGS=-j$(nproc)
export HYPRE_VERSION=2.11.2
export METIS_VERSION=4.0.3
export MFEM_VERSION=3.4
# export GLVIS_VERSION=3.4

success_log="packages/success.log"

if [ -f "${success_log}" ]; then
  echo "Setup has already been performed - nothing to do"
  exit 0
fi

mkdir -p packages
pushd packages

# clone and build hypre
rm -rf hypre-${HYPRE_VERSION} hypre-2.10.0b hypre
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
rm -rf metis-${METIS_VERSION} metis-4.0 metis
wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/OLD/metis-${METIS_VERSION}.tar.gz
tar -xzf metis-${METIS_VERSION}.tar.gz
make --directory metis-${METIS_VERSION}
ln -s metis-${METIS_VERSION} metis
ln -s metis-${METIS_VERSION} metis-4.0
rm metis-${METIS_VERSION}.tar.gz

## # clone and build metis using someone's clone
## # this alternative can be used when glaros.dtc.umn.edu is down
## rm -rf metis-${METIS_VERSION} metis-4.0 metis
## git clone https://github.com/CIBC-Internal/metis-${METIS_VERSION}.git
## cd metis-${METIS_VERSION}
## cmake .
## make
## cd ..
## ln -s metis-${METIS_VERSION} metis
## ln -s metis-${METIS_VERSION} metis-4.0

# clone and build mfem
rm -rf mfem-${MFEM_VERSION} mfem
wget https://github.com/mfem/mfem/archive/v${MFEM_VERSION}.tar.gz
tar -xzf v${MFEM_VERSION}.tar.gz
rm v${MFEM_VERSION}.tar.gz
ln -s mfem-${MFEM_VERSION} mfem
make config MFEM_USE_MPI=YES --directory mfem-${MFEM_VERSION}
make --directory mfem-${MFEM_VERSION}

# glvis is not necessary for the tutorial, but if desired, the user can
# uncomment this section.
#
## # clone and build glvis
## rm -rf glvis-${GLVIS_VERSION} glvis
## wget http://glvis.github.io/releases/glvis-${GLVIS_VERSION}.tgz
## tar -xzf glvis-${GLVIS_VERSION}.tgz
## rm glvis-${GLVIS_VERSION}.tgz
## ln -s glvis-${GLVIS_VERSION} glvis
## make clean --directory glvis-${GLVIS_VERSION}
## make MFEM_DIR=../mfem-${MFEM_VERSION} --directory glvis-${GLVIS_VERSION}

# clone LULESH
git clone https://github.com/LLNL/LULESH.git

# out of packages
popd

# indicate that setup finished successfully
echo
echo "flit tutorial examples setup successfully on $(date)" | \
  tee -a ${success_log}
echo

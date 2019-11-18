#!/bin/bash

set -e
set -u

export MAKEFLAGS=-j$(nproc)
export HYPRE_VERSION=2.11.2
export METIS_VERSION=4.0.3
export MFEM_VERSION=3.4
# export GLVIS_VERSION=3.4

success_log="packages/success.log"
force=false

# implement command-line parsing
while [ $# -gt 0 ]; do
  case $1 in

    -h|--help)
      echo "
Usage:
  $0 [-h|--help]
  $0 [-f|--force]

Description:
  Performs setup of the dependent packages used in the FLiT
  tutorial examples.  It will download and configure MFEM and
  LULESH with their respective dependencies.

  This script does not download or install FLiT.  That can be done
  simply with

    $ git clone https://github.com/PRUNERS/FLiT.git
    $ make --directory FLiT

  The installation documentation can be found in

    FLiT/documentation/installation.md

Options:

  -h, --help   Print this help documentation and exit
  -f, --force  Force setup script to run even if it was previously successful
"
      exit 0
      ;;

    -f|--force)
      force=true
      ;;

    *)
      echo "Unrecognized argument: $1" >&2
      echo "Call $0 --help for more information" >&2
      exit 1
      ;;

  esac

  shift # next argument
done

if [ "$force" != "true" ] && [ -f "${success_log}" ]; then
  echo "Setup has already been performed - nothing to do"
  exit 0
fi

if [ "$force" = "true" ]; then
  echo "Forcing setup"
  echo
  rm -rf ${success_log}
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

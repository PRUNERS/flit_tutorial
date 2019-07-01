# This file is included by the generated Makefile.  If you have some things you
# want to change about the Makefile, it is best to do it here.

PACKAGES_DIR   := $(abspath ../packages)
MFEM_SRC       := $(PACKAGES_DIR)/mfem
HYPRE_SRC      := $(PACKAGES_DIR)/hypre
METIS_SRC      := $(PACKAGES_DIR)/metis-4.0

SOURCE         :=
SOURCE         += $(wildcard *.cpp)
SOURCE         += $(wildcard tests/*.cpp)

# Compiling all sources of MFEM into the tests takes too long for a tutorial
# skip it.  Instead, we link in the MFEM static library
#SOURCE         += $(wildcard ${MFEM_SRC}/fem/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/general/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/linalg/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/mesh/*.cpp)

# just the one source file to see there is a difference
SOURCE         += ${MFEM_SRC}/linalg/densemat.cpp  # where the bug is

CC_REQUIRED    += -I${MFEM_SRC}
CC_REQUIRED    += -I${MFEM_SRC}/examples
CC_REQUIRED    += -isystem ${HYPRE_SRC}/src/hypre/include

LD_REQUIRED    += -L${MFEM_SRC} -lmfem
LD_REQUIRED    += -L${HYPRE_SRC}/src/hypre/lib -lHYPRE
LD_REQUIRED    += -L${METIS_SRC} -lmetis


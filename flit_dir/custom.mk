# This file is included by the generated Makefile.  If you have some things you
# want to change about the Makefile, it is best to do it here.

MFEM_SRC        = $(abspath ../mfem)
HYPRE_SRC       = $(abspath ../hypre)
METIS_SRC       = $(abspath ../metis-4.0)

SOURCE         :=
SOURCE         += $(wildcard *.cpp)
SOURCE         += $(wildcard tests/*.cpp)

# Compiling all sources of MFEM into the tests takes too long for a tutorial
# skip it.  Instead, we link in the MFEM static library
#SOURCE         += $(wildcard ${MFEM_SRC}/fem/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/general/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/linalg/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/mesh/*.cpp)

SOURCE         += ${MFEM_SRC}/linalg/densemat.cpp  # where the bug is

# a few more files to make the search space a bit more interesting
SOURCE         += ${MFEM_SRC}/linalg/matrix.cpp
SOURCE         += ${MFEM_SRC}/fem/gridfunc.cpp
SOURCE         += ${MFEM_SRC}/fem/linearform.cpp
SOURCE         += ${MFEM_SRC}/mesh/point.cpp
SOURCE         += ${MFEM_SRC}/mesh/quadrilateral.cpp

CC_REQUIRED    += -I${MFEM_SRC}
CC_REQUIRED    += -I${MFEM_SRC}/examples
CC_REQUIRED    += -isystem ${HYPRE_SRC}/src/hypre/include

LD_REQUIRED    += -L${MFEM_SRC} -lmfem
LD_REQUIRED    += -L${HYPRE_SRC}/src/hypre/lib -lHYPRE
LD_REQUIRED    += -L${METIS_SRC} -lmetis


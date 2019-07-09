LULESH_DIR     := ../packages/LULESH

SOURCE         += $(wildcard *.cpp)
SOURCE         += $(wildcard tests/*.cpp)
SOURCE         += $(wildcard $(LULESH_DIR)/*.cc)

# Remove lulesh.cc since it defines main().  It is included from LuleshTest.cpp
SOURCE         := $(filter-out $(LULESH_DIR)/lulesh.cc,$(SOURCE))


CC_REQUIRED    += -I$(LULESH_DIR)
CC_REQUIRED    += -DUSE_MPI=1
CC_REQUIRED    += -Wno-unknown-pragmas
CC_REQUIRED    += -Wno-unused-parameter

LD_REQUIRED    += -lm

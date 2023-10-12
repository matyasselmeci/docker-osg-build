OSG_BUILD_IMAGE ?= opensciencegrid/osg-build:latest
OSG_BUILD_REPO ?= opensciencegrid
OSG_BUILD_BRANCH ?= V2-branch
DOCKER ?= docker
SINGULARITY ?= singularity

define dobuild =
DOCKER="$(DOCKER)" \
OSG_BUILD_IMAGE="$(OSG_BUILD_IMAGE)" \
OSG_BUILD_REPO="$(OSG_BUILD_REPO)" \
OSG_BUILD_BRANCH="$(OSG_BUILD_BRANCH)" \
./buildbuilder
endef

.PHONY: all clean

all: osg_build.sif osg_build.tar

clean:
	-rm -f osg_build.tar osg_build.sif osg_build.tar.new

# $@ is the target; $< is the first dependency

osg_build.tar: Dockerfile input/* buildbuilder
	$(dobuild)
	-rm -f $@.new
# have to do this in two steps because docker save won't overwrite an existing file
	"$(DOCKER)" save -o $@.new "$(OSG_BUILD_IMAGE)"
	mv -f $@.new $@

osg_build.sif: osg_build.def osg_build.tar
	"$(SINGULARITY)" build $@ $<

.PHONY: build
build:
	$(dobuild)

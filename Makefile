OSG_BUILD_IMAGE ?= osg-htc/osg-build:v2
OSG_BUILD_IMAGE_OLD ?= opensciencegrid/osg-build:v2
OSG_BUILD_REPO ?= opensciencegrid
OSG_BUILD_BRANCH ?= V2-branch
DOCKER ?= docker
SINGULARITY ?= singularity
REGISTRY ?= hub.opensciencegrid.org

define dobuild =
DOCKER="$(DOCKER)" \
OSG_BUILD_IMAGE="$(OSG_BUILD_IMAGE)" \
OSG_BUILD_REPO="$(OSG_BUILD_REPO)" \
OSG_BUILD_BRANCH="$(OSG_BUILD_BRANCH)" \
./buildbuilder
endef

.PHONY: all push-all clean push-sif push-docker

all: osg_build.sif osg_build.tar

push-all: push-sif push-docker

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

push-docker: osg_build.tar
	$(DOCKER) login $(REGISTRY)
	$(DOCKER) tag $(OSG_BUILD_IMAGE) $(REGISTRY)/$(OSG_BUILD_IMAGE) $(REGISTRY)/$(OSG_BUILD_IMAGE_OLD)
	$(DOCKER) push $(REGISTRY)/$(OSG_BUILD_IMAGE)
	$(DOCKER) push $(REGISTRY)/$(OSG_BUILD_IMAGE_OLD)

push-sif: osg_build.sif
	read -p "Username for $(REGISTRY): " && $(SINGULARITY) registry login --username $$REPLY oras://$(REGISTRY)
	# Can't use the same image name for singularity images as docker images, otherwise pulling the docker image fails with "unsupported media type application/vnd.sylabs.sif.config.v1+json"
	$(SINGULARITY) push $< oras://hub.opensciencegrid.org/$(OSG_BUILD_IMAGE)-sif
	## Intentionally skipping pushing under the old name
	# $(SINGULARITY) push $< oras://hub.opensciencegrid.org/$(OSG_BUILD_IMAGE_OLD)-sif

.PHONY: build
build:
	$(dobuild)
	$(DOCKER) tag $(OSG_BUILD_IMAGE) $(OSG_BUILD_IMAGE_OLD)

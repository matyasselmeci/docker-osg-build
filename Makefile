OSG_BUILD_IMAGE ?= osg-htc/osg-build:v2
OSG_BUILD_IMAGE_OLD ?= opensciencegrid/osg-build:v2
OSG_BUILD_REPO ?= opensciencegrid
OSG_BUILD_BRANCH ?= V2-branch
OSG_BUILD_SIF ?= osg_build.sif
DOCKER ?= docker
SINGULARITY ?= singularity
REGISTRY ?= hub.opensciencegrid.org
TAG_OLD ?= true

define dobuild =
DOCKER="$(DOCKER)" \
OSG_BUILD_IMAGE="$(OSG_BUILD_IMAGE)" \
OSG_BUILD_REPO="$(OSG_BUILD_REPO)" \
OSG_BUILD_BRANCH="$(OSG_BUILD_BRANCH)" \
./buildbuilder
endef

echo:=@echo
echotbl:=@printf "%-30s %s\n"
define varhelp =
@printf "%-30s %s [%s]\n" "$(1)" "$(2)" "$($(1))"
endef

.PHONY: all sif push-all clean push-sif push-docker help

help:
	$(echo) "Targets:"
	$(echo)
	$(echotbl) "build"  "Build the Docker image"
	$(echotbl) "sif"  "Build the Singularity image"
	$(echotbl) "all"  "Builds the SIF and the image"
	$(echotbl) "push-docker"  "Push the Docker image to a Docker registry"
	$(echotbl) "push-sif"  "Push the Singularity image to an ORAS registry"
	$(echotbl) "push-all"  "Push both the Docker image and the Singularity image"
	$(echotbl) "osg_build.tar"  "Build the image and export it to a tar file"
	$(echotbl) "clean"  "Delete build products"
	$(echo)
	$(echo) "Variables:"
	$(echo)
	$(call varhelp,OSG_BUILD_IMAGE,The image tag to build)
	$(call varhelp,OSG_BUILD_IMAGE_OLD,The old image tag to build; ignored if TAG_OLD is false)
	$(call varhelp,OSG_BUILD_REPO,The GitHub org with the osg-build repo to pull the source from)
	$(call varhelp,OSG_BUILD_BRANCH,The branch of osg-build to use)
	$(call varhelp,OSG_BUILD_SIF,The name of the resulting Singularity image)
	$(call varhelp,REGISTRY,The name of the Docker/ORAS registry to upload to)
	$(call varhelp,TAG_OLD,Whether to also tag and push the image under the old name specified by OSG_BUILD_IMAGE_OLD)
	$(call varhelp,DOCKER,The name of the 'docker' binary)
	$(call varhelp,SINGULARITY,The name of the 'singularity' binary)

all: $(OSG_BUILD_SIF) osg_build.tar

push-all: push-sif push-docker

clean:
	-rm -f osg_build.tar $(OSG_BUILD_SIF) osg_build.tar.new

# $@ is the target; $< is the first dependency

osg_build.tar: Dockerfile input/* buildbuilder
	$(dobuild)
	-rm -f $@.new
# have to do this in two steps because docker save won't overwrite an existing file
	$(DOCKER) save -o $@.new "$(OSG_BUILD_IMAGE)"
	mv -f $@.new $@

sif: $(OSG_BUILD_SIF)
$(OSG_BUILD_SIF): osg_build.def osg_build.tar
	$(SINGULARITY) build $@ $<

push-docker: osg_build.tar
	$(DOCKER) login $(REGISTRY)
	$(DOCKER) tag $(OSG_BUILD_IMAGE) $(REGISTRY)/$(OSG_BUILD_IMAGE)
	$(DOCKER) push $(REGISTRY)/$(OSG_BUILD_IMAGE)
	if $(TAG_OLD); then \
		$(DOCKER) tag $(OSG_BUILD_IMAGE) $(REGISTRY)/$(OSG_BUILD_IMAGE_OLD); \
		$(DOCKER) push $(REGISTRY)/$(OSG_BUILD_IMAGE_OLD); \
	fi

push-sif: $(OSG_BUILD_SIF)
	read -p "Username for $(REGISTRY): " && $(SINGULARITY) registry login --username $$REPLY oras://$(REGISTRY)
	# Can't use the same image name for singularity images as docker images, otherwise pulling the docker image fails with "unsupported media type application/vnd.sylabs.sif.config.v1+json"
	$(SINGULARITY) push $< oras://hub.opensciencegrid.org/$(OSG_BUILD_IMAGE)-sif
	if $(TAG_OLD); then \
		$(SINGULARITY) push $< oras://hub.opensciencegrid.org/$(OSG_BUILD_IMAGE_OLD)-sif; \
	fi

.PHONY: build
build:
	$(dobuild)
	if $(TAG_OLD); then \
		$(DOCKER) tag $(OSG_BUILD_IMAGE) $(OSG_BUILD_IMAGE_OLD); \
	fi

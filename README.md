docker-osg-build
================

This is a Docker wrapper around `osg-build` and `osg-koji`, the two primary
tools for doing and getting information about builds in the OSG's Koji build
system. The original scripts are intended for use on RHEL 6- and 7-compatible
systems and have lots of Linux- and Red Hat-specific dependencies that aren't
available on e.g. macOS systems.

The model of these wrapper scripts is to start up a persistent Docker
container with your 'work directory' -- the directory that contains your
checkouts of OSG packages -- mounted inside the container.


Requirements
============
* Docker


Instructions
============

Docker image
------------

Before using these scripts, you will need to pull the Docker image from
DockerHub via `docker pull opensciencegrid/osg-build`.  Alternatively, you can
run the `buildbuilder` script to build it locally.


Starting up the image
---------------------

`docker-osg-build` uses a Docker container that runs in the background. Your
 'work directory,' which contains the packages you are
working with, will be mounted inside the container.

To create the Docker container, run:

    initbuilder <work-dir>

where `<work-dir>` is the directory under which your packages are. For example,
if you have an SVN checkout of https://vdt.cs.wisc.edu/svn/native/redhat in
`~/work/redhat`, you should use `~/work/redhat` for your `<work-dir>`. The
important thing is for your `.svn` directory to be inside the directory,
otherwise `osg-build` won't be able to find the SVN information about the
packages you're building. Similarly, if you're building packages from a Git
repo, your `.git` directory must be inside `<work-dir>`.

`initbuilder` will start a Docker container named `osg-build`. In case Docker
gets shut down, or the container gets turned off for some other reason, run
`docker start osg-build` to start the container back up.


Using the tools
---------------

This product contains two scripts, `exec-osg-koji` and `exec-osg-build` that
run the `osg-koji` and `osg-build` scripts, respectively, inside the Docker
container. You may wish to make shell aliases for them, as in:

    alias osg-build=~/docker-osg-build/exec-osg-build
    alias osg-koji=~/docker-osg-build/exec-osg-koji

The scripts will run `osg-koji` or `osg-build` inside the container, with the
arguments provided.

As long as the packages you are building are inside `<work-dir>` specified
above, `osg-build` will be able to read and write files inside the package
directories.


Example usage
=============

(do once):

    ~/docker-osg-build/buildbuilder
    svn checkout https://vdt.cs.wisc.edu/svn/native/redhat ~/work/redhat
    ~/docker-osg-build/initbuilder ~/work/redhat

Subsequent operations:

    cd ~/work/redhat/osg-ce
    ~/docker-osg-build/exec-osg-build koji --scratch --getfiles .
    ~/docker-osg-build/exec-osg-koji list-tagged osg-3.4-el7-development

Alternatively, test builds in Travis-CI:

    sudo: required
    env:
      - REPO_NAME=${TRAVIS_REPO_SLUG#*/}
        GET_FILES=false

    git:
      depth: false
      quiet: true

    services:
      - docker

    before_install:
      - sudo apt-get update
      - echo 'DOCKER_OPTS="-H tcp://127.0.0.1:2375 -H unix:///var/run/docker.sock -s devicemapper"' | sudo tee /etc/default/docker > /dev/null
      - sudo service docker restart
      - sleep 5
      - sudo docker pull opensciencegrid/osg-build

    script:
      - docker run -v $(pwd):/$REPO_NAME -e REPO_NAME=$REPO_NAME -e GET_FILES=$GET_FILES --cap-add=SYS_ADMIN opensciencegrid/osg-build build-from-github

If you have Source files listed as URLs in your spec file and want to
download them for your Travis-CI builds, set `GET_FILES=true` in the `env`
section of .travis.yml.


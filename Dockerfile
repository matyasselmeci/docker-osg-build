ARG DVER=9
ARG OSG=3.6
FROM almalinux:$DVER
ARG DVER=9
ARG OSG=3.6
ARG LOCALE=C.UTF-8

LABEL name="osg-build"
LABEL maintainer="OSG Software <help@osg-htc.org>"

ENV LANG=$LOCALE
ENV LC_ALL=$LOCALE

COPY input/dist-build.repo         /etc/yum.repos.d/

RUN --mount=type=cache,target=/var/cache,sharing=locked \
 yum -y install https://repo.opensciencegrid.org/osg/${OSG}/osg-${OSG}-el${DVER}-release-latest.rpm \
                epel-release \
                dnf-plugins-core
RUN dnf config-manager --enable osg-minefield
RUN dnf config-manager --setopt install_weak_deps=false --save
RUN if [ ${DVER} = 8   ]; then dnf config-manager --enable powertools; fi
RUN if [ ${DVER} = 9   ]; then dnf config-manager --enable crb; fi
RUN if [ ${OSG}  = 3.6 ]; then dnf config-manager --enable devops-itb; fi
RUN if [ ${OSG}  = 23  ]; then dnf config-manager --enable osg-internal-minefield; fi

RUN --mount=type=cache,target=/var/cache,sharing=locked \
  yum -y install \
    buildsys-macros \
    buildsys-srpm-build \
    osg-build-deps \
    globus-proxy-utils \
    # ^^ sorry, but voms-proxy-init gives me "verification failed" \
    osg-ca-certs

RUN /usr/sbin/install-osg-build.sh

COPY --chmod=0755 input/command-wrapper.sh  /usr/local/bin/command-wrapper.sh
COPY --chmod=0755 input/build-from-github   /usr/local/bin/build-from-github
COPY              input/mock.cfg            /etc/mock/site-defaults.cfg

RUN useradd  -u 1000 -G mock -d /home/build build

USER build
RUN mkdir /home/build/.osg-koji /home/build/.globus

COPY --chown=build:build input/osg-ca-bundle.crt  /home/build/.osg-koji/osg-ca-bundle.crt
COPY --chown=build:build input/config             /home/build/.osg-koji/config

WORKDIR /home/build

ENV KOJI_HUB=koji.opensciencegrid.org

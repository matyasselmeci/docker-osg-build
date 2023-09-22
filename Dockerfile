FROM almalinux:9
ARG OSG=3.6
ARG LOCALE=C.UTF-8

LABEL name="osg-build"
LABEL maintainer="OSG Software <help@osg-htc.org>"

ENV LANG=$LOCALE
ENV LC_ALL=$LOCALE

COPY input /root/input

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
 cp /root/input/dist-build.repo /etc/yum.repos.d/ && \
 dnf -y install https://repo.opensciencegrid.org/osg/${OSG}/osg-${OSG}-el9-release-latest.rpm \
                epel-release \
                dnf-plugins-core \
                which \
                krb5-workstation \
                vim-enhanced && \
 dnf config-manager --enable osg-minefield && \
 dnf config-manager --setopt install_weak_deps=false --save && \
 dnf config-manager --enable crb && \
 case $OSG in \
    3.6) dnf config-manager --enable devops-itb ;; \
    23) dnf config-manager --enable osg-internal-minefield ;; \
 esac && \
 dnf -y install \
   buildsys-macros \
   buildsys-srpm-build \
   'osg-build-deps >= 4' \
   globus-proxy-utils \
   # ^^ sorry, but voms-proxy-init gives me "verification failed" \
   osg-ca-certs && \
   \
   useradd -u 1000 -G mock -d /home/build build && \
   install -d -o build -g build /home/build/.osg-koji /home/build/.globus

ARG OSG_BUILD_BRANCH=master
ARG OSG_BUILD_REPO=https://github.com/opensciencegrid/osg-build

ARG RANDOM=
# ^^ set this to $RANDOM to use RPMs from cache but install a fresh osg-build

RUN \
 /usr/sbin/install-osg-build.sh "$OSG_BUILD_REPO" "$OSG_BUILD_BRANCH" && \
 install /root/input/command-wrapper.sh /usr/local/bin/command-wrapper.sh && \
 install /root/input/build-from-github  /usr/local/bin/build-from-github && \
 install -m 0644 /root/input/mock.cfg   /etc/mock/site-defaults.cfg && \
 install -o build -g build /root/input/config /home/build/.osg-koji/config

USER build
WORKDIR /home/build

# The koji-hub server to use
ENV KOJI_HUB=koji.opensciencegrid.org
ENV KRB5CCNAME=FILE:/dev/shm/krb5cc_1000
ENV KRB5_TRACE=/dev/stderr

FROM almalinux:9
ARG OSG=24
ARG LOCALE=C.UTF-8

LABEL name="osg-build"
LABEL maintainer="OSG Software <help@osg-htc.org>"

ENV LANG=$LOCALE
ENV LC_ALL=$LOCALE

RUN --mount=type=cache,id=dnf-9,target=/var/cache/dnf,sharing=locked \
 dnf -y update

COPY input /root/input

RUN --mount=type=cache,id=dnf-9,target=/var/cache/dnf,sharing=locked \
 cp /root/input/dist-build.repo /etc/yum.repos.d/ && \
 OSGSTR=${OSG}-main && \
 dnf -y install https://repo.osg-htc.org/osg/${OSGSTR}/osg-${OSGSTR}-el9-release-latest.rpm \
                epel-release \
                dnf-plugins-core \
                which \
                rpm-sign \
                pinentry \
                python-unversioned-command \
                krb5-workstation \
                sssd-client \
                && \
 dnf config-manager --enable osg-minefield && \
 dnf config-manager --setopt install_weak_deps=false --save && \
 dnf config-manager --enable crb && \
 dnf config-manager --enable osg-internal-minefield && \
 rm -f /etc/yum.repos.d/osg-next*.repo && \
 dnf -y install \
   buildsys-macros \
   buildsys-srpm-build \
   'osg-build-deps >= 4' \
   tini \
   && \
   useradd -u 1000 -G mock -d /home/build build && \
   install -d -o build -g build /home/build/.osg-koji

ARG OSG_BUILD_BRANCH=V2-branch
ARG OSG_BUILD_REPO=https://github.com/opensciencegrid/osg-build

ARG RANDOM=
# ^^ set this to $RANDOM to use RPMs from cache but install a fresh osg-build

RUN \
 /usr/sbin/install-osg-build.sh "$OSG_BUILD_REPO" "$OSG_BUILD_BRANCH" && \
 install /root/input/command-wrapper.sh /usr/local/bin/command-wrapper.sh && \
 install /root/input/build-from-github  /usr/local/bin/build-from-github && \
 install -m 0644 /root/input/mock.cfg   /etc/mock/site-defaults.cfg && \
 install -o build -g build /root/input/config /home/build/.osg-koji/config && \
 ln -s .osg-koji /home/build/.koji && \
 chown build:build /home/build/.koji

# Add a prompt so people know what they're shelled into
RUN echo 'PS1="[\$? \\u@[osg-build] \\W]\\$ "' > /etc/profile.d/prompt.sh

USER build
WORKDIR /home/build

# The koji-hub server to use
ENV KOJI_HUB=

# Kerberos cache
ENV KRB5CCNAME=DIR:/dev/shm/krb5cc_1000

CMD tini -- sleep infinity

#!/bin/bash

relpath () {
    python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$1" "$2"
}

outside_wd=$1
shift

IFS=  read -r work_dir  </home/build/.work_dir

inside_wd=$(relpath "$outside_wd" "$work_dir")

set -e
if [[ $1 = osg-build ]]; then
    cd ~/work
    if [[ $inside_wd = ../* ]]; then
        echo >&2 "The current directory is '$outside_wd'"
        echo >&2 "which is not under the work directory '$work_dir'"
        echo >&2 "osg-build commands must be run under the work directory"
        exit 2
    fi
    cd "$inside_wd"
fi

certkey=/dev/shm/certkey.pem

if [[ ! -e $certkey ]]; then
    echo >&2 "$certkey doesn't exist, making one"
    umask 077
    (cat ~/.globus/usercert.pem; echo; cat ~/.globus/userkey.pem) > "$certkey.tmp" &&
        tr -d '\015' "$certkey.tmp" > "$certkey" &&
        rm -f "$certkey.tmp"
    umask 022
fi

if [[ ${KOJI_HUB} ]]; then
    sed -i -e "s/^srv = .*/srv = ${KOJI_HUB}/" /home/build/.osg-koji/config
fi

exec "$@"

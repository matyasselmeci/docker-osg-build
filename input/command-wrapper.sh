#!/bin/bash

relpath () {
    python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$1" "$2"
}


strict_work_dir=true
if [[ $1 = "--no-strict-work-dir" ]]; then
    # don't error out if we're outside the work directory
    strict_work_dir=false
    shift
fi


if [[ -x /home/build/work ]]; then
    # we can't enter the work dir anyway; just run the command
    exec "$@"
fi


outside_wd=$1
shift

IFS=  read -r work_dir  </home/build/.work_dir

inside_wd=$(relpath "$outside_wd" "$work_dir")

set -e
if [[ $inside_wd = ../* ]]; then
    if $strict_work_dir; then
        echo >&2 "The current directory is '$outside_wd'"
        echo >&2 "which is not under the work directory '$work_dir'"
        echo >&2 "commands must be run under the work directory"
        exit 2
    fi
else
    cd /home/build/work/"$inside_wd"
fi

if [[ $1 == "osg-build" || $1 == "osg-koji" ]]; then
    certkey=/dev/shm/certkey.pem

    if [[ ! -e $certkey ]]; then
        echo >&2 "$certkey doesn't exist, making one"
        umask 077
        (cat ~/.globus/usercert.pem; echo; cat ~/.globus/userkey.pem) > "$certkey.tmp" &&
            tr -d '\015' "$certkey.tmp" > "$certkey" &&
            rm -f "$certkey.tmp"
        umask 022
    fi
fi

if [[ ${KOJI_HUB} ]]; then
    sed -i -e "s/^koji_hub = .*/koji_hub = ${KOJI_HUB}/" /home/build/.osg-koji/config
fi

exec "$@"

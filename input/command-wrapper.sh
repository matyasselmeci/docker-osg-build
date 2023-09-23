#!/bin/bash

export X509_USER_PROXY=~/.osg-koji/client.crt

get_proxy () {
    #voms-proxy-init -out "$X509_USER_PROXY"
    # ^^ gives me "verification failed"
    grid-proxy-init -out "$X509_USER_PROXY"
}

get_proxy_if_needed () {
    if [[ ! -f $X509_USER_PROXY ]]; then
        get_proxy
        return
    fi

    timeleft=$(grid-proxy-info -timeleft -file "$X509_USER_PROXY")
    ret=$?

    if [[ $ret -ne 0 || $timeleft -lt 60 ]]; then
        get_proxy
    fi
}

relpath () {
    python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$1" "$2"
}


strict_work_dir=true
if [[ $1 = "--no-strict-work-dir" ]]; then
    # don't error out if we're outside the working directory
    strict_work_dir=false
    shift
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
    cd "~/work/$inside_wd"
fi

if [[ $1 == "osg-build" || $1 == "osg-koji" ]]; then
    get_proxy_if_needed
fi

if [[ ${KOJI_HUB} ]]; then
    sed -i -e "s/^srv = .*/srv = ${KOJI_HUB}/" /home/build/.osg-koji/config
fi

exec "$@"

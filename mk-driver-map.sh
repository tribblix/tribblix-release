#!/bin/sh
#
# SPDX-License-Identifier: CDDL-1.0
#
# Copyright 2025 Peter Tribble
#

#
# create the driver maps for a given release
#
THOME=${THOME:-/packages/localsrc/Tribblix}
TOPGATEDIR=${HOME}/Illumos
VERSION=""
ARCH=$(uname -p)

usage() {
    echo "Usage: $0 [-T THOME] [-G directory_of_gates] -V version"
    exit 2
}

bail() {
    echo "ERROR: $1"
    exit 1
}


while getopts "T:G:V:" opt; do
    case $opt in
        T)
	    THOME="$OPTARG"
	    ;;
        G)
	    TOPGATEDIR="$OPTARG"
	    ;;
        V)
	    VERSION="$OPTARG"
	    ;;
	*)
	    usage
	    ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${VERSION}" ]; then
    bail "version must be supplied"
fi

MAPPER="${THOME}/tribblix-build/driver-map-all.sh"

if [ ! -x "${MAPPER}" ]; then
    bail "cannot find mapper script"
fi
if [ ! -d "${TOPGATEDIR}" ]; then
    bail "cannot find any gates"
fi

#
# now we need to find the gates we're going to analyse
# we need both illumos and gfx-drm
#
if [ ! -d "${TOPGATEDIR}/${VERSION}-gate" ]; then
    bail "cannot find ${VERSION} gate"
fi
if [ ! -d "${TOPGATEDIR}/gfx-drm" ]; then
    bail "cannot find ${VERSION} gate"
fi

#
# this is where the output will go
#
if [ ! -d "${VERSION}.${ARCH}" ]; then
    bail "cannot find out directory ${VERSION}.${ARCH}"
fi

#
# now generate the map
#
${MAPPER} -G "${TOPGATEDIR}/${VERSION}-gate" > "${VERSION}.${ARCH}"/driver-map.txt
${MAPPER} -G "${TOPGATEDIR}/gfx-drm" -R drm >> "${VERSION}.${ARCH}"/driver-map.txt


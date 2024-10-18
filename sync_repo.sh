#!/bin/sh
#
# SPDX-License-Identifier: CDDL-1.0
#
# echo and do it
#
case $# in
1)
	PKGDIR=$1
	;;
*)
	echo "Usage: $0 pkg_dir"
	exit 1
	;;
esac

bail() {
    echo "ERROR: $1"
    exit 1
}

if [ ! -d "$PKGDIR" ]; then
    bail "cannot find $PKGDIR"
fi

RELNAME=${PKGDIR##*/}

case $RELNAME in
    *.sparc)
	RELDIR="release-${RELNAME}"
	;;
    *.i386)
	RELDIR="release-${RELNAME%.i386}"
	;;
    *)
	bail "Unrecognized architecture"
	;;
esac

REPOHOST="pkgs.tribblix.org"
REPOROOT="/var/repo"

cd "$PKGDIR" || bail "cd failed"
ZAPFILE=$(ls -1tr TRIBzap-upgrade.*zap|tail -1)
echo scp catalog "${ZAPFILE}" "${ZAPFILE}.sig" "${REPOHOST}:${REPOROOT}/${RELDIR}"
scp catalog "${ZAPFILE}" "${ZAPFILE}.sig" "${REPOHOST}:${REPOROOT}/${RELDIR}"

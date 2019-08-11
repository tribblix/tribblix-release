#!/bin/sh
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

if [ ! -d "$PKGDIR" ]; then
    echo "ERROR: cannot find $PKGDIR"
    exit 1
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
	echo "Unrecognized architecture"
	exit 1
	;;
esac

REPOHOST="pkgs.tribblix.org"
REPOROOT="/var/repo"

cd $PKGDIR
ZAPFILE=`ls -1tr TRIBzap-upgrade.*zap|tail -1`
echo scp catalog ${ZAPFILE} ${ZAPFILE}.sig ${REPOHOST}:${REPOROOT}/${RELDIR}
scp catalog ${ZAPFILE} ${ZAPFILE}.sig ${REPOHOST}:${REPOROOT}/${RELDIR}

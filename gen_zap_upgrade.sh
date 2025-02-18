#!/bin/sh
#
# SPDX-License-Identifier: CDDL-1.0
#
# Copyright 2025 Peter Tribble
#
# creates a zap package
#
THOME=${THOME:-/packages/localsrc/Tribblix}

# this release
RELEASE=""
# the architecture (hardware platform) we're releasing
ARCH=""

usage() {
    if [[ -n $1 ]]; then
	echo "ERROR: $1"
    fi
    echo "Usage: $0 -p platform -r release"
    exit 1
}

while getopts p:r: opt; do
    case $opt in
	p)
	    ARCH=$OPTARG
	    ;;
	r)
	    RELEASE=$OPTARG
	    ;;
    esac
done
shift $((OPTIND - 1))

#
# ARCH and RELEASE are required
#
if [[ -z $ARCH ]]; then
    usage "Platform must be specified"
fi
if [[ -z $RELEASE ]]; then
    usage "Release must be specified"
fi
#
# check we can find ourself
#
if [ ! -d "${RELEASE}.${ARCH}" ]; then
    usage "Cannot find release ${RELEASE}.${ARCH}"
fi

#
# define where we're going to create the package
#
BUILD=$(pwd)
BROOT="/tmp/pct"
if [ ! -d $BROOT ]; then
   mkdir -p ${BROOT}
fi
if [ ! -d $BROOT ]; then
   echo "ERROR: unable to find temporary directory $BROOT"
   exit 1
fi

#
# verify the content exists
#
if [ ! -d "${THOME}/zap" ]; then
    echo "Cannot find source for zap, it should be at ${THOME}/zap"
    exit 1
fi

BDIR="${BROOT}/pkg.$$"
rm -fr ${BDIR}
mkdir $BDIR

#
# put the content into place
#
mkdir -p ${BDIR}/usr/lib/zap
cp "${THOME}/zap/usr/lib/zap/upgrade" ${BDIR}/usr/lib/zap
mkdir -p ${BDIR}/etc/zap
cp "${RELEASE}.${ARCH}/version.current" ${BDIR}/etc/zap
cp "${RELEASE}.${ARCH}/version.list" ${BDIR}/etc/zap

cd $BDIR || exit 1
#
PKGNAME="TRIBzap-upgrade"
PKGVER=$(echo "${RELEASE}"|sed s:m:0.:)
UVER=$(wc -l etc/zap/version.list|awk '{print $1}')
UVER=$((UVER-1))
PKGVER=${PKGVER}.${UVER}

#
cat > pkginfo <<EOF
PKG="$PKGNAME"
NAME="Tribblix upgrade identifier"
VERSION="$PKGVER"
EOF
echo "ARCH=\"$ARCH\"" >> pkginfo
cat "${BUILD}/pkginfo.base" >> pkginfo
echo "i pkginfo=./pkginfo" > pp.$$
(cd ${BDIR} ; pkgproto etc | "${BUILD}"/fixproto) >> pp.$$
(cd ${BDIR} ; pkgproto usr | "${BUILD}"/fixproto) >> pp.$$


# create the package
pkgmk -d ${BROOT} -f pp.$$ -r ${BDIR} ${PKGNAME}
/usr/bin/rm pp.$$
pkgtrans -s ${BROOT} "${BROOT}/${PKGNAME}.${PKGVER}.pkg" ${PKGNAME}
# create the zap file
cd $BROOT || exit 1
# 7z gives us an extra 2-3% reduction in file size
#zip -9 -q -r ${PKGNAME} ${PKGNAME}
rm -f "${PKGNAME}.${PKGVER}.zap" "${PKGNAME}.${PKGVER}.zap.md5" "${PKGNAME}.${PKGVER}.zap.sig"
7za a -tzip -mx=9 -mfb=256 "${PKGNAME}.${PKGVER}.zap" ${PKGNAME}
chmod a+r "${PKGNAME}.${PKGVER}.zap"
cd /
# pregenerate the md5 checksum ready for catalog creation
openssl md5 "${BROOT}/${PKGNAME}.${PKGVER}.zap" | /usr/bin/awk '{print $NF}' > "${BROOT}/${PKGNAME}.${PKGVER}.zap.md5"
# if the passphrase file exists, sign the package
# otherwise, it will have to be signed manually
if [ -f "${HOME}/Tribblix/Sign.phrase" ]; then
    echo ""
    echo "Signing package."
    echo ""
    gpg --detach-sign --no-secmem-warning --passphrase-file "${HOME}/Tribblix/Sign.phrase" "${BROOT}/${PKGNAME}.${PKGVER}.zap"
    if [ -f "${BROOT}/${PKGNAME}.${PKGVER}.zap.sig" ]; then
	echo "Package signed successfully."
	echo ""
    fi
fi
ls -lh "${BROOT}/${PKGNAME}.${PKGVER}.pkg"
ls -lh "${BROOT}/${PKGNAME}.${PKGVER}.zap"
rm -fr "${BROOT}/${PKGNAME}"
rm -fr $BDIR

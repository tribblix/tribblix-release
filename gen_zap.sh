#!/bin/sh
#
# creates a zap package
#
# extracts all the information out of the release string
#
# the only variant we're interested in is lx, which we handle separately
#
THOME=${THOME:-/packages/localsrc/Tribblix}

# this release
RELEASE=""
# this update
URELEASE=""
# the architecture (hardware platform) we're releasing
ARCH=""

usage() {
    if [[ -n $1 ]]; then
	echo "ERROR: $1"
    fi
    echo "Usage: $0 -p platform -r release"
    exit 1
}

while getopts p:r:m:v: opt; do
    case $opt in
	p)
	    ARCH=$OPTARG
	    ;;
	r)
	    RELEASE=$OPTARG
	    ;;
	m)
	    URELEASE=$OPTARG
	    ;;
    esac
done
shift $((OPTIND - 1))

#
# derived parameters
#
PKGVER=`echo ${RELEASE}|sed s:m:0.:`
if [[ -z $URELEASE ]]; then
    RELDIR="${RELEASE}.${ARCH}"
    PKGVER="${PKGVER}.0"
else
    RELDIR="${RELEASE}.${URELEASE}.${ARCH}"
    PKGVER="${PKGVER}.${URELEASE}"
fi
PKGVER=0.${PKGVER}

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
if [ ! -d ${RELDIR} ]; then
    usage "Cannot find release ${RELDIR}"
fi

#
# define where we're going to create the package
#
BUILD=`pwd`
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
if [ ! -d ${THOME}/zap ]; then
    echo "Cannot find source for zap, it should be at ${THOME}/zap"
    exit 1
fi

BDIR="${BROOT}/pkg.$$"
rm -fr ${BDIR}
mkdir $BDIR

#
# put the content into place
#
(cd ${THOME}/zap ; tar cf - etc usr) | ( cd ${BDIR} ; tar xf -)
#
# the upgrade script goes into the zap-upgrade package
#
rm -f ${BDIR}/usr/lib/zap/upgrade
#
# these empty directories are part of the package
#
mkdir -p ${BDIR}/var/zap/cache
mkdir -p ${BDIR}/var/zap/images
mkdir -p ${BDIR}/var/zap/zones
case $RELEASE in
    *lx*)
	mkdir -p ${BDIR}/var/zap/docker
	;;
esac
#
# the zap repo used to contain the metadata
# so delete it just in case
#
rm -f ${BDIR}/etc/zap/repo.list.i386
rm -f ${BDIR}/etc/zap/repo.list.sparc
rm -f ${BDIR}/etc/zap/overlays.list
rm -fr ${BDIR}/etc/zap/repositories
#
# and copy the current metadata
#
mkdir -p ${BDIR}/etc/zap/repositories
cp ${RELDIR}/overlays.list ${BDIR}/etc/zap
cp ${RELDIR}/repo.list ${BDIR}/etc/zap
cp ${RELDIR}/*.repo ${BDIR}/etc/zap/repositories
cp ${RELDIR}/*.ovl ${BDIR}/etc/zap/repositories

cd $BDIR
#
PKGNAME="TRIBzap"
#
cat > pkginfo <<EOF
PKG="$PKGNAME"
NAME="ZAP: Zip Archive Packaging"
VERSION="$PKGVER"
EOF
echo "ARCH=\"$ARCH\"" >> pkginfo
cat ${BUILD}/pkginfo.base >> pkginfo
echo "i pkginfo=./pkginfo" > pp.$$
mkdir -p install
cat > install/depend <<EOF
P TRIBcompress-unzip
P TRIBcurl
P TRIBpackage-svr4
EOF
echo "i depend=./install/depend" >> pp.$$
(cd ${BDIR} ; pkgproto etc | ${BUILD}/fixproto) >> pp.$$
(cd ${BDIR} ; pkgproto usr | ${BUILD}/fixproto) >> pp.$$
(cd ${BDIR} ; pkgproto var | ${BUILD}/fixproto) >> pp.$$


# create the package
pkgmk -d ${BROOT} -f pp.$$ -r ${BDIR} ${PKGNAME}
/usr/bin/rm pp.$$
pkgtrans -s ${BROOT} ${BROOT}/${PKGNAME}.${PKGVER}.pkg ${PKGNAME}
# create the zap file
cd $BROOT
# 7z gives us an extra 2-3% reduction in file size
#zip -9 -q -r ${PKGNAME} ${PKGNAME}
rm -f ${PKGNAME}.${PKGVER}.zap ${PKGNAME}.${PKGVER}.zap.md5 ${PKGNAME}.${PKGVER}.zap.sig
7za a -tzip -mx=9 -mfb=256 ${PKGNAME}.${PKGVER}.zap ${PKGNAME}
chmod a+r ${PKGNAME}.${PKGVER}.zap
cd /
# pregenerate the md5 checksum ready for catalog creation
openssl md5 ${BROOT}/${PKGNAME}.${PKGVER}.zap| /usr/bin/awk '{print $NF}' > ${BROOT}/${PKGNAME}.${PKGVER}.zap.md5
# if the passphrase file exists, sign the package
# otherwise, it will have to be signed manually
if [ -f ${HOME}/Tribblix/Sign.phrase ]; then
    echo ""
    echo "Signing package."
    echo ""
    gpg --detach-sign --no-secmem-warning --passphrase-file ${HOME}/Tribblix/Sign.phrase ${BROOT}/${PKGNAME}.${PKGVER}.zap
    if [ -f ${BROOT}/${PKGNAME}.${PKGVER}.zap.sig ]; then
	echo "Package signed successfully."
	echo ""
    fi
fi
ls -lh ${BROOT}/${PKGNAME}.${PKGVER}.pkg
ls -lh ${BROOT}/${PKGNAME}.${PKGVER}.zap
rm -fr ${BROOT}/${PKGNAME}
rm -fr $BDIR

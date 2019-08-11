#!/bin/sh
#
# creates a release package
#
# extracts all the information out of the release string
#
# the only variant we're interested in is lx, which we handle separately
#

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

while getopts p:r:m:v: opt; do
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
# parameters for os-release
# we have version as constant, without the variant
# so remove lx from the version string if it appears there
# use VARIANT_ID to track variants
#
OSNAME="Tribblix"
OSVERSION=`echo $RELEASE | sed s:lx::`
OSID="tribblix"
OSID_LIKE="illumos"
OSHOME_URL="http://www.tribblix.org/"
case $RELEASE in
    *lx*)
	OSVARIANT_ID="omnitribblix"
	;;
    *)
	OSVARIANT_ID="tribblix"
	;;
esac

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
if [ ! -d ${RELEASE}.${ARCH} ]; then
    usage "Cannot find release ${RELEASE}.${ARCH}"
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

BDIR="${BROOT}/pkg.$$"
rm -fr ${BDIR}
mkdir $BDIR

#
# put the content into place
#
mkdir -p ${BDIR}/etc
cp ${RELEASE}.${ARCH}/release.txt ${BDIR}/etc/release

#
# os-release
#
touch ${BDIR}/etc/os-release
echo "NAME=${OSNAME}" >> ${BDIR}/etc/os-release
echo "VERSION=${OSVERSION}" >> ${BDIR}/etc/os-release
echo "ID=${OSID}" >> ${BDIR}/etc/os-release
echo "ID_LIKE=${OSID_LIKE}" >> ${BDIR}/etc/os-release
echo "HOME_URL=${OSHOME_URL}" >> ${BDIR}/etc/os-release
echo "VARIANT_ID=${OSVARIANT_ID}" >> ${BDIR}/etc/os-release

cd $BDIR
#
PKGNAME="TRIBrelease-name"
PKGVER=`echo ${RELEASE}|sed s:m:0.:`
#
cat > pkginfo <<EOF
PKG="$PKGNAME"
NAME="Tribblix release identifier"
VERSION="$PKGVER"
EOF
echo "ARCH=\"$ARCH\"" >> pkginfo
cat ${BUILD}/pkginfo.base >> pkginfo
echo "i pkginfo=./pkginfo" > pp.$$
(cd ${BDIR} ; pkgproto etc | ${BUILD}/fixproto) >> pp.$$


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

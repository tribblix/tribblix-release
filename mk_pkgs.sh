#!/bin/ksh
#
# SPDX-License-Identifier: CDDL-1.0
#
# create the packages for a release
#
# there are 3 packages that define a release:
#   TRIBzap
#   TRIBzap-upgrade
#   TRIBrelease-name
#
# originally these were in the main repo, but it makes release management
# easier and more flexible if they live in their own repo
#
# TODO: handle variants
# TODO: construct package versions for upgrade packages (count the
# number of upgrade lines?)
#

# this release
RELEASE=""
# the releases we can upgrade from
UGLIST=""
# the variant of this release, if any
VARIANT=""
# the architecture (hardware platform) we're releasing
ARCH=""
# marker for whether to clone an existing release
DOCLONE=""
# text to describe this version
RELTEXT=""
# where to put the repos (assumed to be ../)
REPODIR="release-repos"

usage() {
    if [[ -n $1 ]]; then
	echo "ERROR: $1"
    fi
    echo "Usage: $0 -p platform -r release [-m micro] [-u upgrades] [-v variant]"
    echo "       $0 -p platform -r release -c old_release -t release_text"
    exit 1
}

#
# argument processing
#
while getopts p:r:c:m:u:v:t: opt; do
    case $opt in
	p)
	    ARCH=$OPTARG
	    ;;
	r)
	    RELEASE=$OPTARG
	    ;;
	c)
	    DOCLONE=$OPTARG
	    ;;
	m)
	    URELEASE=$OPTARG
	    ;;
	u)
	    UGLIST="$UGLIST $OPTARG"
	    ;;
	v)
	    VARIANT=$OPTARG
	    ;;
	t)
	    RELTEXT="$OPTARG"
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
# if cloning, create the new clone and exit
# a clone has new repos for: illumos, release, tribblix, and overlays
#
# all a clone does is create and populate the directory, you need to run
# this script again to create all the packages
#
# the idea here is that you may wish to manually modify the parameters
# of a new release prior to package creation
#
if [[ -n $DOCLONE ]]; then
    if [[ -n $UGLIST ]]; then
	usage "cannot clone with an upgrade list"
    fi
    if [[ -n $URELEASE ]]; then
	usage "cannot clone with a micro release"
    fi
    if [ ! -d "${DOCLONE}.${ARCH}" ]; then
	usage "Cannot find $DOCLONE to act as clone source"
    fi
    #
    # handle variants
    # the main Tribblix repo is shared; everything else is a variant name
    #
    TRELEASE=${RELEASE}
    DISTRONAME="Tribblix"
    if [[ -n $VARIANT ]]; then
	RELEASE=${RELEASE}${VARIANT}
	case $VARIANT in
	    lx)
		DISTRONAME="OmniTribblix"
		;;
	    *)
		echo "Unrecognized variant, hoping for the best"
		;;
	esac
    fi
    if [ -d "${RELEASE}.${ARCH}" ]; then
	usage "New release ${RELEASE}.${ARCH} already exists"
    else
	echo "Creating ${RELEASE}.${ARCH}"
	if [[ -z $RELTEXT ]]; then
	    RELTEXT="${DISTRONAME} ${TRELEASE}"
	fi
	mkdir -p "${RELEASE}.${ARCH}"
	if [ -d "${RELEASE}.${ARCH}" ]; then
	    cp "${DOCLONE}.${ARCH}"/* "${RELEASE}.${ARCH}"
	    sed -i s:/overlays-${DOCLONE}:/overlays-${RELEASE}: "${RELEASE}.${ARCH}/tribblix.ovl"
	    sed -i s:/tribblix-${DOCLONE}:/tribblix-${TRELEASE}: "${RELEASE}.${ARCH}/tribblix.repo"
	    sed -i s:/illumos-${DOCLONE}:/illumos-${RELEASE}: "${RELEASE}.${ARCH}/illumos.repo"
	    sed -i s:/release-${DOCLONE}:/release-${RELEASE}: "${RELEASE}.${ARCH}/release.repo"
	    # source for /etc/release
	    echo "${RELTEXT}" > "${RELEASE}.${ARCH}/release.txt"
	    # current version for upgrader
	    echo "${RELEASE}" > "${RELEASE}.${ARCH}/version.current"
	    UGURL=$(grep '^URL=' "${RELEASE}.${ARCH}/release.repo" | sed s:URL=::)
	    # milestone releases have different numbering
	    NRELEASE=$(echo "${RELEASE}"|sed s:m:0.0.:)
	    echo "${RELEASE}|${UGURL}TRIBzap.${NRELEASE}.0.zap|${RELTEXT}" > "${RELEASE}.${ARCH}/version.list"
	    exit 0
	else
	    usage "Cannot create ${RELEASE}.${ARCH}"
	fi
    fi
fi

#
# if a variant, the release will include the variant name
#
if [[ -n $VARIANT ]]; then
    RELEASE=${RELEASE}${VARIANT}
fi

#
# the main release directory must exist
#
if [ ! -d "${RELEASE}.${ARCH}" ]; then
    usage "Release directory ${RELEASE}.${ARCH} must exist"
fi

#
# we cannot give an upgrade list for a micro release, as it should
# be inherited from the main release
#
# all other releases must have an upgrade list
#
if [[ -n $URELEASE ]]; then
    if [[ -n $UGLIST ]]; then
	usage "Cannot specify an upgrade list with a micro release"
    fi
    if [ -f "${RELEASE}.${ARCH}/upgrade.list" ]; then
	UGLIST=$(cat "${RELEASE}.${ARCH}/upgrade.list")
    else
	usage "Unable to find upgrade list"
    fi
else
    if [[ -z $UGLIST ]]; then
	usage "Must specify an upgrade list"
    fi
fi

#
# every release we claim upgradeability from must exist
#
# this is checked after we determine the dynamic upgrade list for
# micro releases, so we can sanity-check
#
# but is checked before we populate the file for a new release, so
# we avoid populating that with bad data
#
for ugr in $UGLIST
do
    if [ ! -d "${ugr}.${ARCH}" ]; then
	usage "Upgradeable directory ${ugr}.${ARCH} must exist"
    fi
done

#
# record the list of releases we can upgrade from
# any subsequent micro release inherits this list
# the list will only have content if we're not creating a micro release
#
if [[ -n $UGLIST ]]; then
    echo "$UGLIST" > "${RELEASE}.${ARCH}/upgrade.list"
fi

#
# if this is a micro release, then this script is responsible for
# creating the new release directory, and updating the repo metadata
# for the illumos and release repositories - the tribblix and overlay
# repositories are shared between micro releases based on a given release
#
if [[ -n $URELEASE ]]; then
    if [ ! -d "${RELEASE}.${URELEASE}.${ARCH}" ]; then
	echo "Creating ${RELEASE}.${URELEASE}.${ARCH}"
	mkdir -p "${RELEASE}.${URELEASE}.${ARCH}"
	if [ -d "${RELEASE}.${URELEASE}.${ARCH}" ]; then
	    cp "${RELEASE}.${ARCH}"/* "${RELEASE}.${URELEASE}.${ARCH}"
	    sed -i s:/illumos-${RELEASE}:/illumos-${RELEASE}.${URELEASE}: "${RELEASE}.${URELEASE}.${ARCH}/illumos.repo"
	    sed -i s:/release-${RELEASE}:/release-${RELEASE}.${URELEASE}: "${RELEASE}.${URELEASE}.${ARCH}/release.repo"
	    # source for /etc/release
	    RELTEXT=$(cat "${RELEASE}.${ARCH}/release.txt")
	    echo "${RELTEXT} update ${URELEASE}" > "${RELEASE}.${URELEASE}.${ARCH}/release.txt"
	    # current version for upgrader
	    echo "${RELEASE}.${URELEASE}" > "${RELEASE}.${URELEASE}.${ARCH}/version.current"
	    UGURL=$(grep '^URL=' "${RELEASE}.${URELEASE}.${ARCH}/release.repo" | sed s:URL=::)
	    # milestone releases have different numbering
	    NRELEASE=$(echo "${RELEASE}"|sed s:m:0.0.:)
	    echo "${RELEASE}.${URELEASE}|${UGURL}TRIBzap.${NRELEASE}.${URELEASE}.zap|${RELTEXT} update ${URELEASE}" > "${RELEASE}.${URELEASE}.${ARCH}/version.list"
	else
	    usage "Cannot create ${RELEASE}.${URELEASE}.${ARCH}"
	fi
    fi
fi

echo "ARCH: $ARCH"
echo "RELEASE: $RELEASE"
echo "UGLIST: $UGLIST"
echo "VARIANT: $VARIANT"
echo "URELEASE: $URELEASE"

#
# construct package versions
# milestone releases have different numbering
#
ZRELEASE=$(echo "${RELEASE}"|sed s:m:0.0.:)
RRELEASE=$(echo "${RELEASE}"|sed s:m:0.:)
if [[ -n $URELEASE ]]; then
    THISREL=${RELEASE}.${URELEASE}
    ZPKGVER=${ZRELEASE}.${URELEASE}
    RPKGVER=${RRELEASE}.${URELEASE}
else
    THISREL=${RELEASE}
    ZPKGVER=${ZRELEASE}.0
    RPKGVER=${RRELEASE}.0
fi

#
# there's just one zap and release-name package and its version is fixed
#
mkdir -p "../${REPODIR}/${THISREL}.${ARCH}"
echo "Creating TRIBzap package version ${ZPKGVER} for ${THISREL}.${ARCH}"
if [[ -n $URELEASE ]]; then
    ./gen_zap.sh -p "${ARCH}" -r "${RELEASE}" -m "${URELEASE}"
else
    ./gen_zap.sh -p "${ARCH}" -r "${RELEASE}"
fi
cp /tmp/pct/TRIBzap."${ZPKGVER}".zap* "../${REPODIR}/${THISREL}.${ARCH}"
echo "Creating TRIBrelease-name package version ${RPKGVER} for ${THISREL}.${ARCH}"
if [[ -n $URELEASE ]]; then
    ./gen_release.sh -p "${ARCH}" -r "${RELEASE}" -m "${URELEASE}"
else
    ./gen_release.sh -p "${ARCH}" -r "${RELEASE}"
fi
cp /tmp/pct/TRIBrelease-name."${RPKGVER}".zap* "../${REPODIR}/${THISREL}.${ARCH}"

#
# now construct the list of potential upgrade targets
#
# if a release, explicitly allow upgrades from the specified
# list of prior releases and all their updates
#
# if a micro release, explicitly allow upgrades from the specified
# list of prior releases, and all their updates, and from all prior
# micro versions of this release
#
# we update the version.list file in all the upgrade targets by copying
# the one from the target release, if it's not already there
#

NRELEASE=$(echo "${RELEASE}"|sed s:m:0.:)
if [[ -n $URELEASE ]]; then
    for ugr in "${RELEASE}".*."${ARCH}" "${RELEASE}.${ARCH}"
    do
	if [ -d "${ugr}" ]; then
	    NVER=$(echo "$ugr"|sed s:.${ARCH}::)
	    GOTVER=$(awk -F'|' -v rver="$THISREL" '{if ($1 == rver) print}' "${ugr}/version.list")
	    if [[ -z $GOTVER ]]; then
		cat "${THISREL}.${ARCH}/version.list" >> "${ugr}/version.list"
	    fi
	    UVER=$(wc -l "${ugr}/version.list"|awk '{print $1}')
	    UVER=$((UVER-1))
	    NRELEASE=$(echo "${NVER}"|sed s:m:0.:)
	    PKGVER="${NRELEASE}.${UVER}"
	    echo "Creating TRIBzap-upgrade package version ${PKGVER} for ${ugr}"
	    mkdir -p "../${REPODIR}/${ugr}"
	    ./gen_zap_upgrade.sh -p "${ARCH}" -r "${NVER}"
	    cp /tmp/pct/TRIBzap-upgrade."${PKGVER}".zap* "../${REPODIR}/${ugr}"
	fi
    done
else
    PKGVER="${NRELEASE}.0"
    echo "Creating TRIBzap-upgrade package version ${PKGVER} for ${RELEASE}.${ARCH}"
    mkdir -p "../${REPODIR}/${RELEASE}.${ARCH}"
    ./gen_zap_upgrade.sh -p "${ARCH}" -r "${RELEASE}"
    cp /tmp/pct/TRIBzap-upgrade."${PKGVER}".zap* "../${REPODIR}/${RELEASE}.${ARCH}"
fi
for ug in $UGLIST
do
    for ugr in $(echo ${ug}{.*,}.${ARCH})
    do
	if [ -d "${ugr}" ]; then
	    NVER=$(echo "$ugr"|sed s:.${ARCH}::)
	    GOTVER=$(awk -F'|' -v rver="$THISREL" '{if ($1 == rver) print}' "${ugr}/version.list")
	    if [[ -z $GOTVER ]]; then
		cat "${THISREL}.${ARCH}/version.list" >> "${ugr}/version.list"
	    fi
	    UVER=$(wc -l "${ugr}/version.list"|awk '{print $1}')
	    UVER=$((UVER-1))
	    NRELEASE=$(echo "${NVER}"|sed s:m:0.:)
	    PKGVER="${NRELEASE}.${UVER}"
	    echo "Creating TRIBzap-upgrade package version ${PKGVER} for ${ugr}"
	    mkdir -p "../${REPODIR}/${ugr}"
	    ./gen_zap_upgrade.sh -p "${ARCH}" -r "${NVER}"
	    cp /tmp/pct/TRIBzap-upgrade."${PKGVER}".zap* "../${REPODIR}/${ugr}"
	fi
    done
done

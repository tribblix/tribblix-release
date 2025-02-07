#!/bin/ksh
#
# SPDX-License-Identifier: CDDL-1.0
#
# Copyright 2025 Peter Tribble
#
# catalog format is
#  name|version|dependencies|size|md5|
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

#
# prefer zap as we can get dependencies, and it's quicker
#
# want to make the release catalog from the main zap package,
# the release package (those two never change)
# and the most recent upgrade package
#
cd "$PKGDIR" || exit 1
for ZPKG in TRIBzap.*.zap TRIBrelease*.zap $(ls -1tr TRIBzap-upgrade.*zap|tail -1)
do
  DEPLIST=""
  PNAME=${ZPKG%%.*}
  PF=${ZPKG%.zap}
  PKGVERS=${PF#*.}
  PKGSIZE=$(/bin/ls -l "${ZPKG}" | /usr/bin/awk '{print $5}')
  if [ "${ZPKG}.md5" -nt "${ZPKG}" ]; then
    PKGMD5=$(/bin/cat "${ZPKG}.md5")
  else
    PKGMD5=$(openssl md5 "${ZPKG}" | /usr/bin/awk '{print $NF}')
    /bin/rm -f "${ZPKG}.md5"
    echo "$PKGMD5" > "${ZPKG}.md5"
  fi
  DEPLIST=$(bash zipgrep '^P' "$ZPKG" "${PNAME}/install/depend" 2>/dev/null |awk '{printf("%s ", $2)}')
  echo "${PNAME}|${PKGVERS}|${DEPLIST}|${PKGSIZE}|${PKGMD5}|" | sed 's: |:|:'
done

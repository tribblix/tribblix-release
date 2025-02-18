#!/bin/sh
#
# SPDX-License-Identifier: CDDL-1.0
#
# Copyright 2025 Peter Tribble
#
# update a catalog and edit it
#
if [ ! -d "$1" ]; then
    exit 1
fi

./gen_catalog.sh "$1" > "${1}"/catalog
emacs "${1}"/catalog
rm -f "${1}"/catalog~

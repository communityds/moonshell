#!/usr/bin/env bash
#
# PRIVATE FUNCTION CHAINLOADING
#
# 'private' is a directory that is excluded from git. If you wish to use
# private libraries you can create shell files in this location, or use
# the more preferred overlay_dir.
#

source ${MOON_LIB}/moonshell.sh

if [[ -d ${MOON_LIB}/private ]]; then
    _moonshell_source ${MOON_LIB}/private
elif [[ -w ${MOON_LIB} ]]; then
    mkdir -p "${MOON_LIB}/private" 2>/dev/null
fi


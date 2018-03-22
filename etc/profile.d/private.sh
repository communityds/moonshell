#
# PRIVATE VARIABLE CHAINLOADING
#
# 'private' is a directory that is excluded from git. If you wish to use
# private libraries you can create shell files in this location, or use
# the more preferred overlay_dir.
#
if [[ -d "${MOON_PROFILE}/private" ]]; then
    _moonshell_source ${MOON_PROFILE}/private
elif [[ -w ${MOON_PROFILE} ]]; then
    mkdir -p "${MOON_PROFILE}/private" 2>/dev/null
fi


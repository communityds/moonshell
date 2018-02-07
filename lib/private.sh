#
# PRIVATE FUNCTION CHAINLOADING
#
# 'private' is a directory that is excluded from git. If you wish to use
# private libraries you can create shell files in this location, or use
# the more preferred overlay_dir.
#

if [[ -d ${MOON_LIB}/private ]]; then
    _moonshell_source ${MOON_LIB}/private
else
    mkdir -p "${MOON_LIB}/private"
fi


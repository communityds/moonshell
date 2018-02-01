#
# PRIVATE VARIABLE CHAINLOADING
#
# 'private' is a directory that is excluded from git. If you wish to use
# private libraries, just create the directory, or symlink to a location
# where you are tracking your senstive files.
#
if [[ -d "${MOON_PROFILE}/private" ]] || [[ -L "${MOON_PROFILE}/private" ]]; then
    _moonshell_source ${MOON_PROFILE}/private
fi


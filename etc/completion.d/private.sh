#
# PRIVATE COMPLETION CHAINLOADING
#
# 'private' is a directory that is excluded from git. If you wish to use
# private libraries, just create the directory, or symlink to a location
# where you are tracking your senstive files.
#
if [[ -d "${MOON_COMPLETION}/private" ]] || [[ -L "${MOON_COMPLETION}/private" ]]; then
    _moonshell_source "${MOON_COMPLETION}/private"
fi


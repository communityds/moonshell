#
# PRIVATE COMPLETION CHAINLOADING
#
# 'private' is a directory that is excluded from git. If you wish to use
# private libraries, just create the directory, or symlink to a location
# where you are tracking your senstive files.
#
if [[ -d "${ENV_COMPLETION}/private" ]] || [[ -L "${ENV_COMPLETION}/private" ]]; then
    _moonshell_source "${ENV_COMPLETION}/private"
fi


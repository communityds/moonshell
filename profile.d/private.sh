#
# PRIVATE VARIABLE CHAINLOADING
#
# Note: 'private' must be a directory
if [[ -d "${ENV_PROFILE}/private" ]] || [[ -L "${ENV_PROFILE}/private" ]]; then
    for private_file in $(find "${ENV_PROFILE}/private/" ${ENV_FIND_OPTS} -name '*.sh'); do
        source ${private_file}
    done
fi


#
# PRIVATE VARIABLE CHAINLOADING
#
if [[ -d "${ENV_ROOT}/private" ]]; then
    for private_file in $(find "${ENV_ROOT}/profile.d/private/" ${ENV_FIND_OPTS} -name '*.sh'); do
        source ${private_file}
    done
fi


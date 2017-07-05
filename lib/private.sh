#
# PRIVATE FUNCTION CHAINLOADING
#
if [[ -d ${ENV_LIB}/private ]]; then
    for private_file in $(find "${ENV_LIB}/private/" ${ENV_FIND_OPTS} -name '*.sh'); do
        source ${private_file}
    done
fi


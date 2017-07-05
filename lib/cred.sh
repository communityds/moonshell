#
# CREDENTIAL FUNCTIONS
#
export ENV_CREDS="${HOME}/.aws"
export AWS_CREDS="${ENV_CREDS}/credentials"
export AWS_CONFIG="${ENV_CREDS}/config"

[[ ! -d "${ENV_CREDS}" ]] && mkdir -p "${ENV_CREDS}"
chmod 0700 ${ENV_CREDS}

[[ ! -f "${AWS_CREDS}" ]] && touch "${AWS_CREDS}"
chmod 0400 "${AWS_CREDS}"

[[ ! -f "${AWS_CONFIG}" ]] && touch "${AWS_CONFIG}"
chmod 0600 "${AWS_CONFIG}"


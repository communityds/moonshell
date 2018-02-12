#!/usr/bin/env bash
#
# CREDENTIAL FUNCTIONS
#
export MOON_CREDS="${HOME}/.aws"
export AWS_CREDS="${MOON_CREDS}/credentials"
export AWS_CONFIG="${MOON_CREDS}/config"

[[ ! -d "${MOON_CREDS}" ]] && mkdir -p "${MOON_CREDS}"
chmod 0700 ${MOON_CREDS}

[[ ! -f "${AWS_CREDS}" ]] && touch "${AWS_CREDS}"
chmod 0400 "${AWS_CREDS}"

[[ ! -f "${AWS_CONFIG}" ]] && touch "${AWS_CONFIG}"
chmod 0600 "${AWS_CONFIG}"


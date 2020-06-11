#!/usr/bin/env bash
#
# AWS FUNCTION LOADING
#
_moonshell_source "${MOON_LIB}/aws"

aws_accounts () {
    if [[ -z ${AWS_ACCOUNTS-} ]]; then
        echoerr "ERROR: Unset variable: AWS_ACCOUNTS"
        return 1
    fi
}


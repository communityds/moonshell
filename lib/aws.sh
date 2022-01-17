#!/usr/bin/env bash
#
# AWS FUNCTION LOADING
#
_moonshell_source "${MOON_LIB}/aws"

# This is sensitive information. Set it as an array in etc/profile.d/private/
# which is .gitignored
aws_accounts () {
    if [[ -z ${AWS_ACCOUNTS[@]-} ]]; then
        echoerr "ERROR: \${AWS_ACCOUNTS[@]} is unset."
        return 1
    else
        echo ${AWS_ACCOUNTS[@]}
    fi
}


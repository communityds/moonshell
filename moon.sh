#!/usr/bin/env bash
#
# MoonShell Initialiser: 'The One Ring'
#
# Sourcing this file loads in all lib/ files and prepends bin/ to PATH
#
# This project is based upon https://github.com/pingram3030/bashenv which is a
# custom and dynamic environment that can easily be built upon. Custom
# libraries can be placed in lib/private/ and custom variables in
# profile.d/private/; these locations are auto-loaded (*.sh).
#
# The changes here in most likely will not be pushed back upstream, but
# functional changes should be ported.
#
# Copyright: Phil Ingram (pingramdotau@gmaildotcom)
#

[[ ${DEBUG-} ]] && set -x


#
# GLOBAL VARIABLES
#
export ENV_ROOT="${HOME}/.moonshell"

export ENV_BIN="${ENV_ROOT}/bin"
export ENV_COMPLETION="${ENV_ROOT}/completion.d"
export ENV_FIND_OPTS="-maxdepth 1 -type f"
export ENV_LIB="${ENV_ROOT}/lib"
export ENV_PROFILE="${ENV_ROOT}/profile.d"
export ENV_USR="${ENV_ROOT}/usr"
export ENV_UPDATE_INTERVAL=5 # minutes
export ENV_VAR="${ENV_ROOT}/var"


#
# PATH MODIFICATION
#
[[ -z ${PRE_ENV_PATH-} ]] && export PRE_ENV_PATH="${PATH}"

[[ ! "${PATH}" =~ "${ENV_BIN}" ]] \
    && export PATH=${ENV_BIN}:${PATH}

#
# SOURCE ALL THE THINGS
#
for lib_file in $(find ${ENV_LIB}/ ${ENV_FIND_OPTS} -name '*.sh'); do
    source "${lib_file}"
done

for profile_file in $(find ${ENV_PROFILE}/ ${ENV_FIND_OPTS} -name '*.sh'); do
    source "${profile_file}"
done

for completion_file in $(find "${ENV_COMPLETION}/" ${ENV_FIND_OPTS} -name '*.sh'); do
    source ${completion_file}
done


# When we have been sourced by a script $(basename $0) will be the name of the
# parent script, not bash. If a person has made a script called "bash"... Well,
# it would be irresponsible for us to make a work around for their gross and
# negligent incompetence.
if [[ ! $(basename $0) == "bash" ]]; then
    # Now that we are not running in a shell treat all undefined variables and
    # non-zero exit codes as serious and exit.
    set -eu

    echoerr "INFO: Checking environment"

    # If this is unset then aws-creds has most likely not been run. aws-creds
    # sets up the credentials, and some other things, as env vars to be used by
    # the aws-cli
    [[ -z ${AWS_DEFAULT_PROFILE-} ]] \
        && echoerr "ERROR: You do not have creds set up in your environment. Try 'aws-creds'" \
        && exit 1

    # aws-cli uses this and it enables a more dynamic environment
    [[ -z ${AWS_REGION-} ]] \
        && echoerr "ERROR: AWS_REGION is unset." \
        && exit 1

    # The magic sauce
    if [[ ! -f ${PWD}/Moonfile.rb ]]; then
        echoerr "ERROR: Moonfile.rb is not present in CWD"
        exit 1
    else
        # APP_NAME is the root to the greater majority of scripts herein working.
        export APP_NAME=$(grep app_name Moonfile.rb | tr -d "'" | awk '{print $NF}')
    fi

    # Only output this info if we have been called from a script to keep the
    # basic terminal clean
    echoerr "INFO: Moonshell is loaded"
fi


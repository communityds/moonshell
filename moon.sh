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
export ENV_FIND_OPTS="-mindepth 1 -maxdepth 1 -type f"
export ENV_LIB="${ENV_ROOT}/lib"
export ENV_PROFILE="${ENV_ROOT}/profile.d"
export ENV_USR="${ENV_ROOT}/usr"
export ENV_UPDATE_INTERVAL=5 # minutes
export ENV_VAR="${ENV_ROOT}/var"


#
# SELF CHECK
#
# This enables moon.sh to be sourced, and if not 'installed' will work through
# creating symlinks, updating .bashrc/.bash_profile and installing gems
#
# In Vagrant $0 is "-bash". basename doesn't like "-b"
moonshell_dir="$(realpath $(dirname ${BASH_SOURCE[0]}))"
if [[ $(basename "x$0") =~ "bash"$ ]]; then
    source "${moonshell_dir}/lib/common.sh"
    source "${moonshell_dir}/lib/moonshell.sh"
    _moonshell_self_check ${moonshell_dir}
else
    source ${ENV_LIB}/common.sh
fi


#
# PATH MODIFICATION
#
[[ -z ${PRE_ENV_PATH-} ]] && export PRE_ENV_PATH="${PATH}"

[[ ! "${PATH}" =~ "${ENV_BIN}" ]] \
    && export PATH=${ENV_BIN}:${PATH}


#
# SCRIPT INITIALISATION
#
# When we have been sourced by a script $(basename $0) will be the name of the
# parent script, not bash. If a person has made a script called "bash"... Well,
# it would be irresponsible for us to make a work around for their gross and
# negligent incompetence.
if [[ ! $(basename "x$0") =~ "bash"$ ]]; then
    # Now that we are not running in a shell treat all undefined variables and
    # non-zero exit codes as serious and exit.
    set -eu

    # If AWS_DEFAULT_PROFILE is unset then aws-creds has most likely not been
    # run and nothing AWS related will work; either in moonshot or moonshell.
    # `aws-creds` sets up the credentials as ENV vars to be used by the aws-cli
    [[ -z ${AWS_DEFAULT_PROFILE-} ]] \
        && echoerr "ERROR: You do not have creds set up in your environment. Try 'aws-creds'" \
        && exit 1

    # aws-cli uses this and it enables a more dynamic environment
    [[ -z ${AWS_REGION-} ]] \
        && echoerr "ERROR: AWS_REGION is unset." \
        && exit 1

    # APP_NAME is needed by the greater majority of scripts.
    if [[ ! -f ${PWD}/Moonfile.rb ]]; then
        echoerr "ERROR: Moonfile.rb is not present in CWD"
        exit 1
    else
        export APP_NAME=$(grep app_name Moonfile.rb | tr -d "'" | awk '{print $NF}')
    fi

    # Source all the things!!!
    for lib_file in $(find ${ENV_LIB}/ ${ENV_FIND_OPTS} -name '*.sh'); do
        source "${lib_file}"
    done

    for profile_file in $(find ${ENV_PROFILE}/ ${ENV_FIND_OPTS} -name '*.sh'); do
        source "${profile_file}"
    done

    for completion_file in $(find "${ENV_COMPLETION}/" ${ENV_FIND_OPTS} -name '*.sh'); do
        source ${completion_file}
    done
fi


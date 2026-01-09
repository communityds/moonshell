#!/usr/bin/env bash
#
# Welcome to the MoonShell initialiser
#
# Sourcing this file sources all files in lib/ and etc/ and prepends bin/ to
# PATH.
#
# Custom libraries can be created in lib/private/ and custom variables defined
# in etc/profile.d/private/; these locations are auto-sourced, but .gitignore'd
#
# Copyright: Phil Ingram (pingramdotau@gmaildotcom)
#

if [[ ${DEBUG-} == true ]]; then
    set -x
fi


#
# GLOBAL VARIABLES
#
if [[ -z ${MOON_ROOT-} ]]; then
    export MOON_ROOT="$(dirname ${BASH_SOURCE[0]})"
fi
# realpath resolves symlinks which can be handy
export MOON_ROOT_REALPATH="$(realpath ${MOON_ROOT})"

export MOON_SHELL="${MOON_ROOT}/moon.sh"

export MOON_BIN="${MOON_ROOT}/bin"
export MOON_ETC="${MOON_ROOT}/etc"
export MOON_LIB="${MOON_ROOT}/lib"
export MOON_USR="${MOON_ROOT}/usr"

# Not all users on a system can write to their ${HOME}
if [[ -w ${HOME} ]]; then
    export MOON_HOME="${HOME}/.moonshell"
    if [[ ! -d ${MOON_HOME} ]]; then
        mkdir -m 0700 -p ${MOON_HOME}
    fi
else
    export MOON_HOME="${MOON_ROOT}"
fi

# MOON_VAR is used for persisting of ephemeral data such as state, completion
# scripts, log and application output. It is primarily used by console users,
# does not need to be writable by service users, but must be set and exist.
export MOON_VAR="${MOON_HOME}/var"
if [[ -w ${MOON_HOME} ]] && [[ ! -d ${MOON_VAR} ]]; then
    mkdir ${MOON_VAR}
fi

export MOON_COMPLETION="${MOON_ETC}/completion.d"
export MOON_PROFILE="${MOON_ETC}/profile.d"

export MOON_FIND_OPTS="-mindepth 1 -maxdepth 1"


#
# SELF CHECK
#
# This enables moon.sh to be sourced, and if not 'installed' will work through
# creating symlinks, updating .bashrc/.bash_profile and installing gems
#
if [[ ${MOON_ROOT} =~ " " ]]; then
    echo "ERROR: The path to moon.sh can not contain spaces: '${MOON_ROOT}'" 1>&2
    return 1
fi

source ${MOON_LIB}/common.sh
source ${MOON_LIB}/moonshell.sh
source ${MOON_LIB}/overlay.sh


#
# PROFILES
#
# As with files in /etc/profile.d, profile files in Moonshell should be used to
# define variables and other less dynamic things. Functions should not reside
# here, but if they do, they must work outside of a moonshell initialised
# environment. Handy things to define in etc/profile.d/private:
#   * AWS_ACCOUNTS[@]
#   * AWS_REGION
_moonshell_source ${MOON_PROFILE}


#
# COMPLETE
#
# Bash has great functionality, via simple functions, to make options to
# scripts and functions tab completable; which aids productivity and ease of
# use.
_moonshell_source ${MOON_COMPLETION}

#
# PATH MODIFICATION
#
[[ -z ${MOON_PATH_PRE-} ]] && export MOON_PATH_PRE="${PATH}"
overlay_path_prepend ${MOON_BIN}


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

    # Several AWS env vars already exist, but for consistency of namespacing
    # we are creating some extras. For a list of currently supported variables:
    # https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html
    #
    # AWS_AUTH is default true, but it can be set to false to signal that a script
    # does not require credentials and authentication.
    if [[ -z ${AWS_AUTH-} ]] || [[ ! ${AWS_AUTH} == false ]]; then
        # The script/process requires credentials
        if [[ -z ${AWS_ACCESS_KEY_ID-} ]]; then
            if curl -sI --connect-timeout 1 http://169.254.169.254 | grep -q 'HTTP/1.1 200 OK'; then
                # Is an AWS server
                INSTANCE_ROLE_ARN="$(curl -s http://169.254.169.254/latest/meta-data/iam/info \
                    | jq -r '.InstanceProfileArn')"
                echoerr "INFO: Using instance profile: ${INSTANCE_ROLE_ARN##*/}"
                unset INSTANCE_ROLE_ARN
            else
                # TODO remove the test for AWS_ACCOUNT_NAME once AWS_AUTH is ubiquitous
                if [[ -z ${AWS_ACCOUNT_NAME-} ]]; then
                    echoerr "ERROR: AWS authentication is required and no AWS_ACCESS_KEY_ID was found"
                    exit 1
                fi
            fi
        else
            # TODO remove the test for AWS_ACCOUNT_NAME once AWS_AUTH is ubiquitous
            if [[ -z ${AWS_ACCOUNT_NAME-} ]]; then
                if [[ -z ${AWS_SECRET_ACCESS_KEY-} ]]; then
                    echoerr "ERROR: Unset AWS_SECRET_ACCESS_KEY"
                    exit 1
                fi
            fi
        fi

    fi

    # AWS_REGION is required by the majority of AWS cli commands, so we should
    # set a default.
    if [[ -z ${AWS_REGION-} ]]; then
        export AWS_REGION="ap-southeast-2"
    fi

    # Most scripts in bin/ build off of ${APP_NAME} which is programatically
    # set below. For those that don't need APP_NAME, i.e. can be run from
    # anywhere in the filesystem, they can export ${MOON_FILE} as false and
    # bypass this failure mode.
    #
    # We only support an APP_NAME which does not contain hyphens. We make
    # this assumption to simplify code and deliberately choose one side of
    # the fence; Mea culpa.
    if [[ ${MOON_FILE-} == false ]]; then
        # Nothing to see here
        true
    elif [[ -f "${PWD}/moonshell/moonshell.sh" ]]; then
        source "${PWD}/moonshell/moonshell.sh"

        if [[ -z ${APP_NAME-} ]]; then
            echoerr "FATAL: Unset variable: APP_NAME"
            exit 255
        elif [[ ! ${APP_NAME} =~ ^[a-z0-9A-Z_]*$ ]]; then
            echoerr "ERROR: APP_NAME may only contain alpha-numeric characters and underscores"
            exit 1
        fi
    else
        echoerr "ERROR: You must be in the root of a product's repo"
        exit 1
    fi

    # Source the rest of the things!!!
    _moonshell_source ${MOON_LIB}
    _moonshell_source ${MOON_COMPLETION}

    # Auto-source the CWD, unless we are in /
    # /etc/profile.d/*.sh can not be sourced with `set -u`
    if [[ ! $(realpath "${PWD}") =~ ^/$ ]]; then
        overlay_dir "${PWD}"
    else
        true
    fi
fi


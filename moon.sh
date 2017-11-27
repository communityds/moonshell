#!/usr/bin/env bash
#
# MoonShell Initialiser: 'The One Ring'
#
# Sourcing this file loads in all lib/ files and prepends bin/ to PATH
#
# This project is based upon https://github.com/pingram3030/bashenv which is a
# custom and dynamic environment that can easily be built upon. Custom
# libraries can be placed in lib/private/ and custom variables in
# etc/profile.d/private/; these locations are auto-loaded (*.sh).
#
# The changes here in most likely will not be pushed back upstream, but
# functional changes should be ported.
#
# Copyright: Phil Ingram (pingramdotau@gmaildotcom)
#

[[ ${DEBUG-} ]] && set -x

# If moon.sh is sourced by root or a user with passwordless sudo, then assume
# a system level installation
if [[ $(whoami) =~ ^root$ ]] || $(sudo -n -v 2>/dev/null); then
    export MOON_ROOT="$(realpath $(dirname ${BASH_SOURCE[0]}))"
else
    export MOON_ROOT="${HOME}/.moonshell"
fi


#
# GLOBAL VARIABLES
#
export MOON_ROOT_REALPATH="$(realpath ${MOON_ROOT})"

export MOON_SHELL="${MOON_ROOT}/moon.sh"

export MOON_BIN="${MOON_ROOT}/bin"
export MOON_ETC="${MOON_ROOT}/etc"
export MOON_LIB="${MOON_ROOT}/lib"
export MOON_USR="${MOON_ROOT}/usr"
export MOON_VAR="${MOON_ROOT}/var"

export MOON_COMPLETION="${MOON_ETC}/completion.d"
export MOON_OVERLAY="${MOON_ETC}/overlay.d"
export MOON_PROFILE="${MOON_ETC}/profile.d"

export MOON_FIND_OPTS="-mindepth 1 -maxdepth 1"
export MOON_UPDATE_INTERVAL=5 # minutes


#
# SELF CHECK
#
# This enables moon.sh to be sourced, and if not 'installed' will work through
# creating symlinks, updating .bashrc/.bash_profile and installing gems
#
# In Vagrant $0 is "-bash". basename doesn't like "-b"
moonshell_dir="$(realpath $(dirname ${BASH_SOURCE[0]}))"
if [[ ${moonshell_dir} =~ " " ]]; then
    echo "ERROR: The path to moon.sh can not contain spaces: '${moonshell_dir}'" 1>&2
    return 1
fi

if [[ $(basename "x$0") =~ "bash"$ ]]; then
    source ${moonshell_dir}/lib/common.sh
    source ${moonshell_dir}/lib/moonshell.sh
    source ${moonshell_dir}/lib/overlay.sh
    _moonshell_check ${moonshell_dir}
else
    source ${MOON_LIB}/common.sh
    source ${MOON_LIB}/moonshell.sh
    source ${MOON_LIB}/overlay.sh
fi


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
# PATH MODIFICATION
#
[[ -z ${PRE_MOON_PATH-} ]] && export PRE_MOON_PATH="${PATH}"
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

    # Originally we used AWS_DEFAULT_PROFILE to label accounts and it was used
    # by lib/aws/bastion.sh. This was not portable because when connected to a
    # remote host, where you have passed through AWS env vars, aws-cli commands
    # fail because there is no ~/.aws/{config,credentials} configured.
    # tl;dr; AWS_DEFAULT_PROFILE is reserved and should only be set where you
    # have run `aws configure`; this is a machine local thing.
    # 
    # As we still need a way of differentiating accounts and hosts etc we
    # instead set AWS_ACCOUNT_NAME. This is not currently used by aws-cli, so
    # we appropriate it here. This should be set to the defining suffix
    # required; for example 'production' or 'development' are used in bastion
    # functions to set the name of the bastion to use; 'bastion-production' or
    # 'bastion-development', which in turn should reference host entries in
    # ~/.ssh/config
    #
    [[ -z ${AWS_ACCOUNT_NAME-} ]] \
        && echoerr "ERROR: 'AWS_ACCOUNT_NAME' is unset. aws-creds?" \
        && exit 1

    # aws-cli uses this and it enables a more dynamic environment
    [[ -z ${AWS_REGION-} ]] \
        && echoerr "ERROR: 'AWS_REGION' is unset." \
        && exit 1

    # Most scripts in bin/ build off of ${APP_NAME} which is programatically
    # set from `Moonfile.rb`. For those that don't need APP_NAME, i.e. can be
    # run from anywhere in the filesystem, they can export ${MOON_FILE} to
    # false and bypass this failure mode.
    if [[ ! -f ${PWD}/Moonfile.rb ]]; then
        if [[ ! ${MOON_FILE-} == false ]]; then
            echoerr "ERROR: Moonfile.rb is not present in CWD"
            exit 1
        fi
    else
        # To define the environment name from the stack name we split on
        # hyphens and strip the first component. This was a decision for
        # simplicity; deal with it and use underscores in your app name
        # instead
        export APP_NAME=$(grep app_name Moonfile.rb | tr -d "'" | awk '{print $NF}')
        if [[ ! ${APP_NAME} =~ ^[a-z0-9A-Z_]*$ ]]; then
            echoerr "ERROR: APP_NAME may only contain alpha-numeric characters and underscores"
            exit 1
        fi
    fi

    # Source the rest of the things!!!
    _moonshell_source ${MOON_LIB}
    _moonshell_source ${MOON_COMPLETION}
fi


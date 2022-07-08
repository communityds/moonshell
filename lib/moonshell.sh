#!/usr/bin/env bash
#
# MOONSHELL FUNCTIONS
#

_moonshell () {
    local options=($@)
    [[ -z ${options} ]] \
        && _moonshell_help \
        || _moonshell_getopts ${options[@]}
}

_moonshell_getopts () {
    OPTIND=1
    local optspec=":hrst" OPTARG=($@)
    # Long options don't actually work in this case, but it works enough to
    # give the illusion that it does.
    while getopts "${optspec}" opt; do
        case "${opt}" in
            h|help)
                _moonshell_help
                return 0
            ;;
            r|reset)
                _moonshell_reset
                return 0
            ;;
            t|test)
                _moonshell_test
                return 0
            ;;
        esac
    done
}

_moonshell_help () {
    cat << EOF
Usage: _moonshell [-h|--help] [-r|--reset] [-s|--setup]
Perform basic functions for Moonshell.

    -h, --help      show this help and exit
    -r, --reset     remove all var files and regenerate self
    -t, --test      run bashate and markdownlint
EOF
}

_moonshell_reset () {
    echoerr "INFO: Reinitialising Moonshell."
    # This should never evaluate as true, but rm -Rf would cause lulz if it
    # ever does...
    [[ -z ${MOON_VAR-} ]] \
        && echoerr "ERROR: \${MOON_VAR} is unset" \
        && return 1

    read -n 1 -p "You are about to recursively remove files from '${MOON_VAR}'. Are you sure? (y/N): " I_KNOW_WHAT_I_AM_DOING
    [[ ! ${I_KNOW_WHAT_I_AM_DOING} =~ ^[yY]$ ]] \
        && echoerr "INFO: Aborting on user request" \
        && return 0 \
        || echo

    rm -Rvf ${MOON_VAR}/*

    source ${MOON_SHELL}
}

_moonshell_source () {
    local source_dir=$1

    for source_file in $(find $(realpath "${source_dir}")/ ${MOON_FIND_OPTS} -name '*.sh'); do
        source "${source_file}"
    done
}

_moonshell_test () {
    pushd ${MOON_ROOT} >/dev/null
        echoerr "Testing shell..."
        bashate -i E006,E042 moon.sh $(find -name "*.sh")
        echoerr "Testing markdown..."
        mdl $(find -name "*.md")
    popd >/dev/null
}


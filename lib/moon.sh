#
# MOONSHELL FUNCTIONS
#

# 'moonshell' is a tab completion conflict with 'moonshot' and it's rare that a
# person should need to use this function during their every day, but it is a
# nice to have for when you are developing it. In the mean time, however, we
# 'hide' it as '_moonshell' to not impact on functionality
_moonshell (){
    local options=($@)
    [[ -z ${options} ]] \
        && _moonshell_help \
        || _moonshell_getopts ${options[@]}
}

_moonshell_help (){
    cat << EOF
Usage: _moonshell [-h|--help] [-r|--reset] [-s|--setup]
Perform basic functions for Moonshell.

    -h, --help      show this help and exit
    -r, --reset     remove all var files and regenerate self
    -s, --setup     install self in to the shell of the running user
    -t, --test      run bashate, rubocop and markdownlint
EOF
}

_moonshell_getopts (){
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
            s|setup)
                _moonshell_setup
                return 0
            ;;
            t|test)
                _moonshell_test
                return 0
            ;;
        esac
    done
}

_moonshell_reset (){
    echoerr "Reinitialising Moonshell.."
    [[ -z ${ENV_VAR-} ]] \
        && echoerr "ERROR: \${ENV_VAR} is unset; run 'moonshell --setup'" \
        && return 1 \
        || rm -Rf ${ENV_VAR}/*
    source ${ENV_ROOT}/moon.sh
}

_moonshell_setup (){
    echoerr "Running Moonshell setup"
    ${ENV_ROOT}/install
    moonshell
}

_moonshell_test (){
    pushd ${ENV_ROOT} >/dev/null
        echoerr "Testing shell..."
        bashate -i E006,E042 moon.sh install $(find -name "*.sh")
        echoerr "Testing markdown..."
        mdl $(find -name "*.md")
        echoerr "Testing ruby..."
        bundle exec rubocop -D
    popd >/dev/null
}


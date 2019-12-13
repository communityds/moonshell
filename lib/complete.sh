#!/usr/bin/env bash
#
# BASH COMPLETION FUNCTIONS
#

source ${MOON_LIB}/moonshell.sh

export MOON_VAR_COMPLETE="${MOON_VAR}/complete"

if [[ ! -d ${MOON_VAR_COMPLETE} ]] && [[ -w ${MOON_VAR} ]]; then
    mkdir -p "${MOON_VAR_COMPLETE}" 2>/dev/null
elif [[ -d ${MOON_VAR_COMPLETE} ]]; then
    _moonshell_source ${MOON_VAR_COMPLETE}
fi

# Private Functions
#
# _complete_path is used almost exclusively by 'environment'. You parse in a
# base path that contains git repos, not the repo itself - its parent, it
# iterates through each directory looking for '.git', adds it to an array and
# then calls _create_function with the name of the containing folder and the
# array of git repos.
#
_complete_path () {
    if [[ -z ${1-} ]]; then
        echoerr "Usage: ${FUNCNAME[0]} REPOS_ROOT [EXTRA_OPTIONS]"
        return
    else
        local path="$1"
        shift
        local -a extra_options=(${@-})
    fi

    local environment completion_f dir repos

    environment=$(basename ${path})
    completion_f="${MOON_VAR_COMPLETE}/${environment}.sh"

    local -a repos

    for dir in $(find ${path}/ -maxdepth 1 -type d -not -wholename '*/'); do
        [[ -d "${dir}/.git" ]] && repos+=($(basename ${dir}))
    done

    _complete_function "${environment}" ${repos[@]} ${extra_options[@]-}
    source "${MOON_VAR_COMPLETE}/${environment}.sh"
}

# Create a completion function for $environment from an array of its subdirs
#
_complete_function () {
    local environment="$1" opts="${@:2}"

    cat > "${MOON_VAR_COMPLETE}/${environment}.sh" <<EOF
#!/usr/bin/env bash
#
# Completion file for ${environment}
#

_${environment} () {
    local cur prev opts
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    opts="${opts}"

    if [[ \$COMP_CWORD -eq 1 ]] ; then
        COMPREPLY=( \$(compgen -W "\${opts}" -- \${cur}) )
        return 0
    fi
}

complete -F _${environment} ${environment}

EOF

    source "${MOON_VAR_COMPLETE}/${environment}.sh"
}


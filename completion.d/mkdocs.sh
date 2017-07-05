#!/usr/bin/env bash
#
# This is the autocomplete file for moonshell
#

_mkdocs() {
    local cur prev option
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    option="build gh-deploy json new serve"

    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${option}" -- ${cur}) )
    fi

    return 0
}

complete -F _mkdocs mkdocs

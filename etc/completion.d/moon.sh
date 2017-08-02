#!/usr/bin/env bash
#
# This is the autocomplete file for moonshell
#

__moonshell () {
    local cur prev option
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    option="-h --help -r --reset -s --setup -t --test"

    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${option}" -- ${cur}) )
    fi

    return 0
}

complete -F __moonshell _moonshell

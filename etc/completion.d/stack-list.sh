#!/usr/bin/env bash
#
#
#

_stack_list () {
    local cur prev option
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    option="all parents"

    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${option}" -- ${cur}) )
    fi

    return 0
}

complete -F _stack_list stack-list

#!/usr/bin/env bash
#
# COMMON FUNCTIONS
#
csv () {
    if [[ $# -lt 1 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} ARRAY"
        return 1
    fi
    local IFS=","
    echo "$*"
}

echoerr () {
    # echo a message to STDERR instead of STDOUT
    echo "${@-}" >&2
}

bash_rc_file () {
    local uname=$(uname)
    case ${uname} in
        Linux) echo ".bashrc";;
        Darwin) echo ".bash_profile";;
        *)
            echoerr "ERROR: Unsupported system: ${uname}"
            return 1
        ;;
    esac
}

contains () {
    if [[ $# -lt 2 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} \$SEARCH_ITEM \${BASH_ARRAY[@]}"
        echoerr "Returns 0 if search_item is in bash_array, 1 if not."
        return 1
    fi

    local i
    for i in "${@:2}"; do
        [[ "$i" == "$1" ]] && return 0
    done
    return 1
}

choose () {
    if [[ $# -lt 1 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} \${BASH_ARRAY[@]}"
        return 1
    fi

    # Parse in an array and the user's selection will be echoed as a string
    local -a items=($@)
    local count choice

    for ((count = 0; count < ${#items[@]}; count += 1)); do
        echoerr "  ${count}: ${items[$count]}"
    done

    [[ ${#items[@]} -lt 2 ]] \
        && read -p "Choice [0]: " \
        || read -p "Choice [0-$((${#items[@]} - 1))]: "

    if [[ ${REPLY-} =~ ^[0-9]+$ ]]; then
        if [[ -z ${items[$REPLY]-} ]]; then
            echoerr "ERROR: Choice is invalid: ${REPLY}"
            return 1
        else
            echo "${items[$REPLY]}"
            return 0
        fi
    else
        echoerr "ERROR: Choice is not numeric: ${REPLY-}"
        return 1
    fi
}

choose_default () {
    if [[ $# -lt 1 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} \${BASH_ARRAY[@]}"
        return 1
    fi

    # ARGV[0] is the default value to be returned.
    # It does not have to exist in the array, that is the user's choice..
    local default=$1
    shift
    local -a items=($@)
    local count choice

    for ((count = 0; count < ${#items[@]}; count += 1)); do
        echoerr "  ${count}: ${items[$count]}"
    done

    [[ ${#items[@]} -lt 2 ]] \
        && read -p "Choice [0] (default: ${default}): " \
        || read -p "Choice [0-$((${#items[@]} - 1))] (default: ${default}): "

    if [[ ${REPLY-} =~ ^[0-9]+$ ]]; then
        if [[ -z ${items[$REPLY]-} ]]; then
            echoerr "ERROR: Choice is invalid: ${REPLY}"
            return 1
        else
            echo "${items[$REPLY]}"
            return 0
        fi
    else
        echo "${default}"
    fi
}

generate_password () {
    # 32 characters, 64 possibilities per character
    # 6.277101735×10⁵⁷ combinations
    # 6,277,101,735,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    # 6.277 million million million million million million million
    # 6.277 billion billion billion billion billion
    # 6.277 trillion trillion trillion trillion
    # 6.277 million quillion quillion quillion
    # 6.277 trillion pentillion pentillion
    # 6.277 billion hexillion hexillion
    # 6.277 quillion dodecillion
    which sha256sum &>/dev/null \
        && local sha_cmd="sha256sum" \
        || local sha_cmd="shasum -a 256"

    echo "$(uuidgen | ${sha_cmd} | base64 | head -c 32)"
}

matches () {
    if [[ $# -lt 2 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} \$MATCH_ITEM \${BASH_ARRAY[@]}"
        echoerr "Returns 0 if match_item matches any element of the array, 1 if not."
        return 1
    fi

    local i
    for i in "${@:2}"; do
        [[ "$i" =~ "$1" ]] && return 0
    done
    return 1
}

prompt_boolean () {
    if [[ $# -lt 1 ]] || [[ ${1-} =~ ^yes|no$ ]]; then
        echoerr "Usage: ${FUNCNAME[0]} \"QUESTION\" [yes|no]"
        return 1
    else
        local question="${1}"
        local default=${2-yes}
    fi

    [[ ! ${default} =~ ^yes|no$ ]] \
        && echoerr "WARNING: Invalid default: ${default}" \
        && echoerr "INFO: Assuming default of 'yes'" \
        && default=yes

    [[ ${default} == yes ]] \
        && default_options="Y/n" \
        || default_options="y/N"

    read -n1 -p "${question} (${default_options}): "

    if [[ -z ${REPLY} ]]; then
        # if the default is yes, return true. if the default is no, return true
        return 0
    elif [[ ${REPLY-} =~ y|Y ]]; then
        echoerr
        [[ ${default} == yes ]] \
            && return 0 \
            || return 1
    elif [[ ${REPLY} =~ n|N ]]; then
        echoerr
        [[ ${default} == no ]] \
            && return 0 \
            || return 1
    else
        echoerr "WARNING: Invalid option: ${REPLY}"
        echoerr "INFO: Assuming: ${default}"
        return 0
    fi
}

prompt_no () {
    prompt_boolean "${1}" no
    return $?
}

prompt_yes () {
    prompt_boolean "${1}" yes
    return $?
}

pipe_failure () {
    # Return true if a non-zero exit code was found
    #
    # if pipe_failure ${PIPESTATUS[@]}; then handle_error; fi
    local -a pipestatus=(${@-})
    local status

    for status in ${pipestatus[@]}; do
        if [[ ${status} -ne 0 ]]; then
            return 0
        fi
    done

    return 1
}

safe_source () {
    if [[ $# -lt 1 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} BASH_LIBRARY"
        return 0
    else
        local library="${1}"
    fi


    if [[ -f "${library}" ]]; then
        echoerr "INFO: Safe source: ${library}"
        source "${library}"
    else
        echoerr "WARNING: No file to source: ${library}"
        return 0
    fi
}


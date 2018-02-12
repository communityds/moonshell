#!/usr/bin/env bash
#
# COMMON FUNCTIONS
#
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
            echoerr "ERROR: Unsupported system '${uname}'"
            return 1
        ;;
    esac
}

contains () {
    [ $# -lt 2 ] \
        && echoerr "Usage: ${FUNCNAME[0]} \$SEARCH_ITEM \${BASH_ARRAY[@]}" \
        && echoerr "Returns 0 if search_item is in bash_array, 1 if not." \
        && return 1
    local i
    for i in "${@:2}"; do
        [[ "$i" == "$1" ]] && return 0
    done
    return 1
}

choose () {
    # Parse in an array and the user's selection will be echoed as a string
    local -a items=($@)
    local count choice

    for ((count = 0; count < ${#items[@]}; count += 1)); do
        echoerr "  ${count}: ${items[$count]}"
    done

    [[ ${#items[@]} -lt 2 ]] \
        && echoerr -n "Choice [0]: " \
        || echoerr -n "Choice [0-$((${#items[@]} - 1))]: "

    read choice

    if [[ ${choice-} =~ ^[0-9]+$ ]]; then
        if [[ -z ${items[$choice]-} ]]; then
            echoerr "ERROR: Choice '${choice}' is invalid."
            return 1
        else
            echo "${items[$choice]}"
            return 0
        fi
    else
        echoerr "ERROR: Choice '${choice-}' is not numeric"
        return 1
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
    echo "$(uuidgen | sha256sum | base64 | head -c 32)"
}

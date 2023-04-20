#!/usr/bin/env bash
#
# OVERLAY FUNCTIONS
#
# The purpose of 'overlay' is to extend functionality of Moonshell. If you
# have developed a library or script that is only relevant to one of your
# Moonshot stacks/projects, then just `overlay_dir $path_to_project`.
#
# overlay_dir:
#   * source ${PWD}/lib/*.sh
#   * source ${PWD}/etc/profile.d/*.sh
#   * source ${PWD}/etc/completion.d/*.sh
#   * PATH=${PWD}/bin:${PATH}

overlay_dir_install () {
    if [[ $# -lt 1 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} PATH_TO_DIR"
        echoerr
        echoerr "Examples:"
        echoerr "  $ overlay_dir_install foo/"
        echoerr "  $ overlay_dir_install /home/bar/baz/"
        return
    elif [[ ! -d "$1" ]]; then
        echoerr "ERROR: '$1' is not a directory"
        return 1
    else
        local dir=$1
    fi

    # We must resolve the dir in case of it being '.'
    local dir_realpath="$(realpath ${dir})"
    local dir_name="$(basename ${dir_realpath})"

    # This dir should be created by ${MOON_PROFILE}/private.sh, but that may
    # not have been sourced yet to do so.
    [[ ! -d "${MOON_PROFILE}/private" ]] && mkdir -p "${MOON_PROFILE}/private"
    local overlay_file="${MOON_PROFILE}/private/overlay-${dir_name}.sh"

    if [[ -f "${overlay_file}" ]]; then
        local existing_dir=$(awk '{print $2}' "${overlay_file}")
        if [[ "${existing_dir}" == "${dir_realpath}" ]]; then
            echoerr "WARNING: Overlay has already installed itself for: ${dir_name}"
            return 0
        else
            echoerr "ERROR: Overlay file '${overlay_file}' already exists, but points to a different dir: ${existing_dir}"
            return 1
        fi
    else
        echoerr "INFO: Installing '${dir_name}' to: ${overlay_file}"
        echo "overlay_dir ${dir_realpath}" > "${overlay_file}"

        echoerr "INFO: Sourcing: ${overlay_file}"
        source ${overlay_file}

        return $?
    fi
}

overlay_dir () {
    if [[ ${1-} ]]; then
        local dir=$1
    else
        echoerr "Usage: ${FUNCNAME[0]} DIRECTORY"
        echoerr
        echoerr "Example:"
        echoerr "  ${FUNCNAME[0]} foo/"
        echoerr "  ${FUNCNAME[0]} /path/to/bar"
        return
    fi

    if [[ -d ${dir}/bin ]]; then
        overlay_path_prepend "$(realpath ${dir}/bin)"
    elif [[ ! -d ${dir} ]]; then
        echoerr "ERROR: Directory does not exist or is not a directory: ${dir}"
        return 1
    fi

    local location
    local -a locations=(lib etc/profile.d etc/completion.d)

    for location in ${locations[@]}; do
        [[ -d "${dir}/${location}" ]] \
            && overlay_source_dir "${dir}/${location}" \
            || true
    done
}

overlay_path_append () {
    if [[ ${1-} ]]; then
        local bin_dir=$1
    else
        echoerr "Usage: ${FUNCNAME[0]} BIN_DIR"
        return
    fi

    if [[ -d ${bin_dir} ]]; then
        if [[ ! "${PATH}" =~ "${bin_dir}" ]]; then
            export PATH=${PATH}:$(realpath ${bin_dir})
        fi
    else
        echoerr "ERROR: Not a directory: ${bin_dir}"
        return 1
    fi
}

overlay_path_prepend () {
    if [[ ${1-} ]]; then
        local bin_dir=$1
    else
        echoerr "Usage: ${FUNCNAME[0]} BIN_DIR"
        return
    fi

    if [[ -d ${bin_dir} ]]; then
        if [[ ! "${PATH}" =~ "${bin_dir}" ]]; then
            export PATH=$(realpath ${bin_dir}):${PATH}
        fi
    else
        echoerr "ERROR: Not a directory: ${bin_dir}'"
        return 1
    fi
}

overlay_self () {
    local script="$0"
    if [[ -L "${script}" ]]; then
        local readlink=$(readlink ${script})
        script="${readlink}"
    fi
    overlay_dir $(dirname "${script}")/../
}

overlay_source_dir () {
    local find_opts=${MOON_FIND_OPTS:--mindepth 1 -maxdepth 1}

    if [[ ${1-} ]]; then
        local source_dir=$1
    else
        echoerr "Usage: ${FUNCNAME[0]} DIR_TO_SOURCE"
        return
    fi

    if [[ ! -d ${source_dir} ]]; then
        echoerr "ERROR: Not a directory: ${source_dir}"
        return 1
    fi

    local source_file
    local -a source_files=($(find ${source_dir}/ ${find_opts} -name '*.sh'))

    for source_file in ${source_files[@]-}; do
        source "${source_file}"
    done
}


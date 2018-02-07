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
        echoerr "Usage: overlay_dir_install PATH_TO_DIR"
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
            echoerr "WARNING: Overlay has already installed itself for '${dir_name}'"
            return 0
        else
            echoerr "ERROR: Overlay file '${overlay_file}' already exists, but points to a different dir: '${existing_dir}'"
            return 1
        fi
    else
        echoerr "INFO: Installing '${dir_name}' in to '${overlay_file}'"
        echo "overlay_dir ${dir_realpath}" > "${overlay_file}"

        echoerr "INFO: Sourcing '${overlay_file}'"
        source ${overlay_file}

        return $?
    fi
}

overlay_dir () {
    local dir=$1
    local -a locations=(lib etc/profile.d etc/completion.d)

    [[ ! -d ${dir} ]] \
        && echoerr "ERROR: '${dir}' does not exist or is not a directory" \
        && return 1

    [[ -d ${dir}/bin ]] && overlay_path_prepend "${dir}/bin"

    local location
    for location in ${locations[@]}; do
        [[ -d "${dir}/${location}" ]] \
            && overlay_source_dir "${dir}/${location}" \
            || true
    done
}

overlay_path_append () {
    local bin_dir=$1

    [[ ! "${PATH}" =~ "${bin_dir}" ]] \
        && export PATH=${PATH}:${bin_dir} \
        || true
}

overlay_path_prepend () {
    local bin_dir=$1

    [[ ! "${PATH}" =~ "${bin_dir}" ]] \
        && export PATH=${bin_dir}:${PATH} \
        || true
}

overlay_source_dir () {
    local source_dir=$1
    local opts=${MOON_FIND_OPTS:--mindepth 1 -maxdepth 1}

    local source_file
    for source_file in $(find ${source_dir}/ ${opts} -name '*.sh'); do
        source "${source_file}"
    done
}


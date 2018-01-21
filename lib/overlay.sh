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
    local dir=$1

    # We must resolve the dir in case of it being '.'
    local dir_realpath="$(realpath ${dir})"
    local dir_name="$(basename ${dir_realpath})"

    local lib_file="${MOON_LIB}/private/overlay-${dir_name}.sh"

    if [[ -f "${lib_file}" ]]; then
        local existing_dir=$(awk '{print $2}' "${lib_file}")
        if [[ "${existing_dir}" == "${dir_realpath}" ]]; then
            echoerr "WARNING: Overlay has already installed itself for '${dir_name}'"
            return 0
        else
            echoerr "ERROR: Overlay file '${lib_file}' already exists, but points to a different dir: '${existing_dir}'"
            return 1
        fi
    else
        echoerr "INFO: Installing '${dir_name}' in to '${lib_file}'"
        echo "overlay_dir ${dir_realpath}" > "${lib_file}"

        echoerr "INFO: Sourcing '${lib_file}'"
        source ${lib_file}

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


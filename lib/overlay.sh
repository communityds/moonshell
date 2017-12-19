#
# OVERLAY FUNCTIONS
#
# The purpose of 'overlay' is to extend functionality of Moonshell. If you
# have developed a library or script that is only relevant to one of your
# Moonshot stacks/projects, then you can overlay a custom bin/, lib/ or
# profile.d/ dir to override default Moonshell behaviour, or extend it.
#

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


#
# BASTION FUNCTIONS
#
bastion () {
    # Only one bastion exists per AWS account inside a 'core' stack.
    # The bastion host in ~/.ssh/config must be set accordingly
    local bastion_hostname="bastion-${AWS_DEFAULT_PROFILE}"
    if [[ "$(grep ${bastion_hostname} ${HOME}/.ssh/config)" == "" ]]; then
        echoerr "ERROR: You do not have configuration set for ${bastion_hostname} in ~/.ssh/config"
        exit 1
    else
        echo -n "${bastion_hostname}"
        return 0
    fi
}

bastion_exec () {
    local cmd=$1

    ssh ${SSH_OPTS} $(bastion) "${cmd}"
}

bastion_exec_host () {
    # Execute a command on a single host
    local stack_name=$1
    local target_host=$2
    local cmd=$3
    local outfile=${4-}

    [[ ${outfile-} ]] \
        && ssh ${SSH_OPTS} $(bastion) "ssh ${SSH_OPTS} ${target_host} ${cmd}" > ${outfile} \
        || ssh ${SSH_OPTS} $(bastion) "ssh ${SSH_OPTS} ${target_host} ${cmd}"
}

bastion_exec_utility () {
    # Execute command on a utility host inside a stack via the bastion
    local stack_name=$1
    local cmd=$2
    local outfile=${3-}
    local target_host=$(bastion_utility_host ${stack_name})

    bastion_exec_host ${stack_name} ${target_host} "${cmd}" ${outfile-}
}

bastion_exec_vhost () {
    # Some host entries are RR records, so will return multiple IPs
    # Execute command on all resolved hosts for a specific domain.
    local stack_name=$1
    local target_host=$2
    local site_fqdn=$3
    shift 3
    local cmd=$*

    bastion_pdsh_host ${stack_name} ${target_host} "cd /var/www/vhost/${site_fqdn}; ${cmd[@]}"
}

bastion_pdsh_host () {
    local stack_name=$1
    local target_host=$2
    local cmd=$3
    local outfile=${4-}

    local target_fqdn="${target_host}.${stack_name}.local"

    [[ ${outfile-} ]] \
        && ssh ${SSH_OPTS} $(bastion) "export PDSH_SSH_ARGS='${SSH_OPTS}'; pdsh -M ssh -w \$(host ${target_fqdn} | awk '{print \$NF}' | paste -sd,) '${cmd}'" > ${outfile} \
        || ssh ${SSH_OPTS} $(bastion) "export PDSH_SSH_ARGS='${SSH_OPTS}'; pdsh -M ssh -w \$(host ${target_fqdn} | awk '{print \$NF}' | paste -sd,) '${cmd}'"
}

bastion_utility_host () {
    local stack_name=$1

    if $(type ssh_target_hostname &>/dev/null); then
        echo "$(ssh_target_hostname ${stack_name})"
    else
        echoerr "INFO: Defaulting target hostname to 'localhost'."
        echoerr "INFO: To override this define the function 'ssh_target_hostname' in ${MOON_LIB}/private"
        echo "localhost"
    fi
}

bastion_upload_file () {
    local stack_name=$1
    local upload_file=$2

    local bastion=$(bastion)
    local file_name="$(basename ${upload_file})"
    local target_host=$(bastion_utility_host ${stack_name})

    echoerr "INFO: Uploading ${file_name} to ${bastion}"
    rsync -e "ssh ${SSH_OPTS}" -vP "${upload_file}" "${bastion}:/tmp/${file_name}"

    echoerr "INFO: Copying ${file_name} to ${target_host}"
    bastion_exec "rsync -e 'ssh ${SSH_OPTS}' -vP '/tmp/${file_name}' '${target_host}:/tmp/${file_name}'"
}


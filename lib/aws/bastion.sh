#!/usr/bin/env bash
#
# BASTION FUNCTIONS
#
bastion () {
    # $(facter virtual)
    # VirtualBox:  virtualbox
    # KVM/Libvirt: kvm
    # AWS/Xen:     xenu|xenhvm
    # Hosts:       physical
    [[ $(uname) == Darwin ]] \
        && local virtual=physical \
        || local virtual=$(facter virtual)

    local bastion_hostname

    if [[ ${virtual} =~ ^(virtualbox|physical)$ ]]; then
        # Only one bastion exists per AWS account inside the 'core' stack.
        # This host should either be set in `~/.ssh/config`,  `/etc/hosts`,
        # or the preferred location of `/etc/ssh/ssh_config`.
        bastion_hostname="bastion-${AWS_ACCOUNT_NAME}"
    elif [[ ${virtual} =~ ^xen(u|hvm)$ ]]; then
        # The 'easiest' way to define the domain of the core stack is to
        # inspect the name of the smtp server, which should always exist and
        # can only ever be an A record. This should never fail provided that
        # a stack is alwys configured to have a central SMTP server, which is
        # an ISM control.
        local smtp_hostname=$(getent hosts smtp | awk '{print $2}')
        local core_domain_suffix="${smtp_hostname#*.}"
        bastion_hostname="bastion.${core_domain_suffix}"
    else
        echoerr "ERROR: Unsupported virtual fact '${virtual}'"
        return 1
    fi

    echo -n "${bastion_hostname}"
}

bastion_admin_hostname () {
    local stack_name=$1

    # The preferred method for choosing an admin host is to export
    # ADMIN_NODE_HOSTNAME. For legacy's sake and to provide more functionality,
    # you can also define the `ssh_target_hostname` function more centrally and
    # have it return the FQDN of the desired hostname.

    if [[ -n ${ADMIN_NODE_HOSTNAME-} ]]; then
        echo "${ADMIN_NODE_HOSTNAME}.${stack_name}.local"
    elif $(type ssh_target_hostname &>/dev/null); then
        echo "$(ssh_target_hostname ${stack_name})"
    else
        echoerr "INFO: Defaulting admin hostname to 'localhost'."
        echoerr "INFO: To override this, 'export ADMIN_NODE_HOSTNAME' to a name of your choosing"
        echo "localhost"
    fi
}

bastion_exec () {
    local cmd=$1

    ssh ${SSH_OPTS} $(bastion) "${cmd}"
}

bastion_exec_admin () {
    # Execute command on an admin host inside a stack via the bastion
    local stack_name=$1
    local cmd=$2
    local outfile=${3-}

    local target_hostname=$(bastion_admin_hostname ${stack_name})

    bastion_exec_host ${target_hostname} "${cmd}" ${outfile-}

    return $?
}

bastion_exec_host () {
    # Execute a command on a single host
    local target_hostname=$1
    local cmd=$2
    local outfile=${3-}

    [[ ${outfile-} ]] \
        && ssh ${SSH_OPTS} ${target_hostname} "${cmd}" > ${outfile} \
        || ssh ${SSH_OPTS} ${target_hostname} "${cmd}"

    return $?
}

bastion_pdsh_host () {
    local target_fqdn=$1
    local cmd="$2"
    local out_file=${3-}

    [[ $(uname) == "Darwin" ]] \
        && echoerr "ERROR: Unsupported OS 'Darwin'" \
        && return 1

    local bastion_host=$(bastion)
    local host_csv="$(bastion_exec "getent hosts ${target_fqdn}" | awk '{print $1}' | paste -sd,)"

    [[ -z ${PDSH_SSH_ARGS-} ]] \
        && export PDSH_SSH_ARGS="${SSH_OPTS} -J ${bastion_host}"

    if [[ ${out_file-} ]]; then
        if [[ ${host_csv} =~ , ]]; then
            echoerr "WARNING: Capturing output from multiple hosts will result in unexpected data"
        fi
        # Because we are capturing raw command output we must use -N
        pdsh -N -R ssh -w ${host_csv} "${cmd}" >${out_file}
        return $?
    else
        pdsh -R ssh -w ${host_csv} "${cmd}"
        return $?
    fi
}

bastion_upload_file () {
    local stack_name=$1
    local upload_file=$2

    local bastion=$(bastion)
    local file_name="$(basename ${upload_file})"
    local target_hostname=$(bastion_admin_hostname ${stack_name})

    echoerr "INFO: Uploading ${file_name} to ${bastion}"
    rsync -e "ssh ${SSH_OPTS}" -vP "${upload_file}" "${bastion}:/tmp/${file_name}"

    echoerr "INFO: Copying ${file_name} to ${target_hostname}"
    bastion_exec "rsync -e 'ssh ${SSH_OPTS}' -vP '/tmp/${file_name}' '${target_hostname}:/tmp/${file_name}'"
}

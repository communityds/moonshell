#!/usr/bin/env bash
#
# AMI FUNCTIONS
#
ami_describe_launch_permissions () {
    local ami_id=$1
    echoerr "INFO: Echoing launch permissions for ami '${ami_id}'"
    # Table output looks purdy with this data
    aws ec2 describe-image-attribute \
        --region ${AWS_REGION} \
        --image-id ${ami_id} \
        --attribute launchPermission \
        --output table
}

ami_describe () {
    local -a ami_ids=$@

    echoerr "INFO: Describing AMIs"
    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --image-ids ${ami_ids[@]} \
        --output table
    return $?
}

ami_deregister () {
    # Deregisters an ${ami_id} and its associated EBS ${snapshot_id}
    local ami_id=$1

    local wait=7

    echoerr "INFO: Finding snapshot for ${ami_id}"
    local snapshot_id=$(aws ec2 describe-snapshots \
        --region ${AWS_REGION} \
        --query "Snapshots[?contains(Description, '${ami_id}')].SnapshotId" \
        --output text)

    echoerr "WARNING: Deleting ${ami_id} and ${snapshot_id} in ${wait} seconds. Ctrl-C to cancel"
    sleep ${wait}

    aws ec2 deregister-image --region ${AWS_REGION} --image-id ${ami_id} \
        && aws ec2 delete-snapshot --region ${AWS_REGION} --snapshot-id ${snapshot_id} \
        || echoerr "ERROR: Failed to deregister ${ami_id}. ${snapshot_id} is preserved"
}

ami_export () {
    local ami_id=$1

    local account
    local accounts=($(aws_accounts))

    echoerr "INFO: Modifying launch permissions for ami '${ami_id}'"
    for account in ${accounts[@]-}; do
        aws ec2 modify-image-attribute \
            --region ${AWS_REGION} \
            --image-id ${ami_id} \
            --launch-permission "{ \"Add\": [{ \"UserId\": \"${account}\" }] }"
    done
}

ami_find_roles () {
    local account_id=$(sts_account_id)

    echoerr "INFO: Finding all AMIs roles"
    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --filter \
            Name=owner-id,Values=${account_id} \
            Name=state,Values=available \
        --query "Images[].Tags[?Key=='role'].Value" \
        --output text \
        | sort \
        | uniq
    return $?
}

ami_info () {
    local ami_id=$1

    ami_validate ${ami_id-}

    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --image-ids ${ami_id} \
        --query "Images[]" \
        | jq '.'
}

ami_list_all () {
    # Return an array of AMI ids
    local account_id=$(sts_account_id)

    echoerr "INFO: Finding all available AMIs owned by ${account_id}"
    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --filter \
            Name=owner-id,Values=${account_id} \
            Name=state,Values=available \
        --query "Images[].ImageId" \
        --output text
    return $?
}

ami_list_role () {
    # Return a sorted array of AMI ids
    local ami_role="$1"
    local account_id=$(sts_account_id)

    if ! contains ${ami_role} $(ami_find_roles); then
        echoerr "ERROR: No AMIs of role ${ami_role} could be found in ${account_id}"
        return 1
    fi

    echoerr "INFO: Finding all ${ami_role} AMIs owned by ${account_id}"
    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --filter \
            Name=owner-id,Values=${account_id} \
            Name=state,Values=available \
            Name=tag:role,Values="${ami_role}" \
        --query "Images[].ImageId" \
        --output text
    return $?
}

ami_list_sorted () {
    local -a ami_ids=$@

    echoerr "INFO: Listing and date sorting AMIs"
    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --image-ids ${ami_ids[@]} \
        | jq -r '.Images|=sort_by(.CreationDate)|.Images[].ImageId'

    return $?
}

ami_validate () {
    local ami_id=$1

    if [[ -z ${ami_id-} ]]; then
        echoerr "ERROR: AMI Id is null"
        return 1
    elif [[ ! ${ami_id} =~ ^ami-[a-f0-9]{17}$ ]]; then
        echoerr "ERROR: AMI Id '${ami_id}' is invalid"
        echoerr "INFO: AMI Id must match regex of '^ami-[a-f0-9]{17}\$'"
        return 1
    else
        return 0
    fi
}


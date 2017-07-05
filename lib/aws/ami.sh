#
# AMI FUNCTIONS
#
ami_export () {
    local ami_id=$1

    local account
    local accounts=($(aws_accounts))

    echoerr "INFO: Modifying launch permissions for ami '${ami_id}'"
    for account in ${accounts[@]-}; do
        aws ec2 modify-image-attribute \
            --image-id ${ami_id} \
            --launch-permission "{ \"Add\": [{ \"UserId\": \"${account}\" }] }"
    done
}

ami_describe () {
    local ami_id=$1
    echoerr "INFO: Echoing launch permissions for ami '${ami_id}'"
    # Table output looks purdy with this data
    aws ec2 describe-image-attribute \
        --image-id ${ami_id} \
        --attribute launchPermission \
        --output table
}

ami_deregister () {
    # Deregisters an ${ami_id} and its associated EBS ${snapshot_id}
    local ami_id=$1

    local wait=7

    echoerr "INFO: Finding snapshot for ${ami_id}"
    local snapshot_id=$(aws ec2 describe-snapshots \
        --query "Snapshots[?contains(Description, '${ami_id}')].SnapshotId" \
        --output text)

    echoerr "WARNING: Deleting ${ami_id} and ${snapshot_id} in ${wait} seconds. Ctrl-C to cancel"
    sleep ${wait}

    aws ec2 deregister-image --image-id ${ami_id} \
        && aws ec2 delete-snapshot --snapshot-id ${snapshot_id} \
        || echoerr "ERROR: Failed to deregister ${ami_id}. ${snapshot_id} is preserved"
}

ami_list_all () {
    # Return an array of AMI ids
    local account_id=$(sts_account_id)

    echoerr "INFO: Finding all available AMIs owned by ${account_id}"
    aws ec2 describe-images \
        --filter \
            Name=owner-id,Values=${account_id} \
            Name=state,Values=available \
        --query "Images[].ImageId" \
        --output text
    return $?
}


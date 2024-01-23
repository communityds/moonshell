#!/usr/bin/env bash
#
# AMI FUNCTIONS
#
ami_describe_launch_permissions () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} AMI_ID"
        return 1
    fi
    local ami_id="$1"

    echoerr "INFO: Echoing launch permissions for: ${ami_id}"
    # Table output looks purdy with this data
    aws ec2 describe-image-attribute \
        --region ${AWS_REGION} \
        --image-id ${ami_id} \
        --attribute launchPermission \
        --output table
}

ami_describe () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} AMI_ID [AMI_ID]"
        return 1
    fi
    local -a ami_ids=(${@})

    echoerr "INFO: Describing AMIs"
    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --image-ids ${ami_ids[@]} \
        --output table
    return $?
}

ami_export () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} AMI_ID"
        return 1
    fi
    local ami_id="$1"

    # AWS_ACCOUNTS
    aws_accounts

    local account

    echoerr "INFO: Modifying launch permissions for: ${ami_id}"
    for account in ${AWS_ACCOUNTS[@]-}; do
        aws ec2 modify-image-attribute \
            --region ${AWS_REGION} \
            --image-id ${ami_id} \
            --launch-permission "{ \"Add\": [{ \"UserId\": \"${account}\" }] }"
    done
}

ami_info () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} AMI_ID"
        return 1
    fi
    local ami_id="$1"

    ami_validate ${ami_id-}

    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --image-ids ${ami_id} \
        --query "Images[]" \
        | jq '.'
}

ami_list_sorted () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} AMI_ID [AMI_ID]"
        return 1
    fi
    local -a ami_ids=(${@})

    echoerr "INFO: Listing and date sorting AMIs"
    aws ec2 describe-images \
        --region ${AWS_REGION} \
        --image-ids ${ami_ids[@]} \
        | jq -r '.Images|=sort_by(.CreationDate)|.Images[].ImageId'

    return $?
}

ami_validate () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} AMI_ID"
        return 1
    fi
    local ami_id="$1"

    if [[ -z ${ami_id-} ]]; then
        echoerr "ERROR: AMI Id is null"
        return 1
    elif [[ ! ${ami_id} =~ ^ami-[a-f0-9]{17}$ ]]; then
        echoerr "ERROR: AMI Id is invalid: ${ami_id}"
        echoerr "INFO: AMI Id must match regex of '^ami-[a-f0-9]{17}\$'"
        return 1
    else
        return 0
    fi
}


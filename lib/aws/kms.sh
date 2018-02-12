#!/usr/bin/env bash
#
# KMS FUNCTIONS
#
kms_list_keys () {
    aws kms list-aliases \
        --region ${AWS_REGION} \
        --query "Aliases[].AliasArn" \
        --output text
    return $?
}

kms_list_keys_detail () {
    local key managed
    local -a keys=($(kms_list_keys))
    [[ -z ${keys[@]-} ]] \
        && echoerr "ERROR: No KMS keys found" \
        && return 1

    for key in ${keys[@]}; do
        managed=$(aws kms describe-key --key-id ${key} \
            --region ${AWS_REGION} \
            --output text \
            --query "KeyMetadata.Origin")
        if [[ ${managed} == "AWS_KMS" ]]; then
            echoerr "INFO: Internal key: ${key}"
        elif [[ ${managed} == "EXTERNAL" ]]; then
            echoerr "INFO: External key: ${key}"
            aws kms describe-key \
                --region ${AWS_REGION} \
                --key-id ${key} \
                --query "KeyMetadata.{Arn:Arn,CreationDate:CreationDate,Description:Description,KeyState:KeyState,ExpirationModel:ExpirationModel}" \
                --output table
            # Key Aliases are not supported for this operation
            #aws kms list-resource-tags \
            #    --key-id ${key} \
            #    --query "Tags" --output table \
            #    --output table
        else
            echoerr "ERROR: The key origin '${managed}' did not match"
            return 1
        fi
    done
}


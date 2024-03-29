#!/usr/bin/env bash
#
# KMS FUNCTIONS
#

kms_id_from_key () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} KMS_KEY"
        return 1
    fi
    local key="$1"

    local key_id

    if [[ ${key} =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
        key_id=${key}
    else
        [[ ! ${key} =~ ^alias ]] \
            && key="alias/${key}" \
            || true

        key_id=$(aws kms list-aliases \
            --region ${AWS_REGION} \
            --query "Aliases[?AliasName=='${key}'].TargetKeyId" \
            --output text)

        [[ -z ${key_id-} ]] \
            && echoerr "ERROR: Could not find ID for key alias: ${key}" \
            && return 1 \
            || true
    fi

    echo ${key_id}
}

kms_list_key_aliases () {
    aws kms list-aliases \
        --region ${AWS_REGION} \
        --query "Aliases[].AliasName" \
        --output text
    return $?
}

kms_list_key_aliases_custom () {
    # Display all non-default KMS keys
    aws kms list-aliases \
        --region ${AWS_REGION} \
        | jq -r '.Aliases[] | select(.AliasName | startswith("alias/aws") | not ) | .AliasName'
    return $?
}

kms_list_key_ids () {
    aws kms list-keys \
        --region ${AWS_REGION} \
        --query "Keys[].KeyId" \
        --output text
    return $?
}

kms_list_keys_detail () {
    local key managed
    local -a keys=($(kms_list_key_ids))
    [[ -z ${keys[@]-} ]] \
        && echoerr "ERROR: No KMS keys found" \
        && return 1

    for key in ${keys[@]}; do
        managed=$(aws kms describe-key \
            --region ${AWS_REGION} \
            --key-id ${key} \
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
        else
            echoerr "ERROR: The key origin '${managed}' did not match"
            return 1
        fi
    done
}

kms_stack_key_id () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    # Because describe-stacks is a heavy, rate limited, API call, attempt to
    # find the alias, named for the stack, first.
    local account_id=$(sts_account_id)
    local kms_key_alias="arn:aws:kms:${AWS_REGION}:${account_id}:alias/${stack_name}"

    local kms_key_id=$(aws kms describe-key \
        --region ${AWS_REGION} \
        --key-id ${kms_key_alias} \
        --query "KeyMetadata.KeyId" \
        --output text)

    if [[ -z ${kms_key_id-} ]]; then
        kms_key_id="$(aws cloudformation describe-stacks \
            --region ${AWS_REGION} \
            --stack-name ${stack_name} \
            --query "Stacks[].Parameters[?starts_with(ParameterValue,'arn:aws:kms')].ParameterValue" \
            --output text)"
    fi

    [[ ${kms_key_id-} ]] \
        && printf "${kms_key_id}" \
        && return 0 \
        || return 1
}


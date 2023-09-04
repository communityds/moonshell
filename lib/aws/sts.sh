#!/usr/bin/env bash
#
# SECURITY TOKEN SERVICE FUNCTIONS
#
sts_account_id () {
    aws sts get-caller-identity \
        --region ${AWS_REGION} \
        --query "Account" \
        --output text
    return $?
}

sts_assume_role () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME ROLE_NAME [DURATION_SECONDS]"
        return 1
    fi

    local stack_name="$1"
    local role="$2"
    local duration="${3-}"

    local role_json=$(aws iam list-roles \
        | jq ".Roles[] \
        | select(.Path == \"/${stack_name}/\") \
        | select(.RoleName | test(\"${role}\"))")

    if [[ -z ${role_json-} ]]; then
        echoerr "ERROR: Could not find role: ${role}"
    fi

    local duration_max=$(echo ${role_json} \
            | jq -r ".MaxSessionDuration")

    local role_arn=$(echo ${role_json} \
            | jq -r ".Arn")

    local role_name=$(echo ${role_json} \
            | jq -r ".RoleName")

    local role_session_name="${USER}-${role}"

    # See: aws sts assume-role help
    if [[ -z ${duration-} ]]; then
        duration=${duration_max}
    elif [[ ! ${duration} =~ ^[0-9]+$ ]]; then
        echoerr "ERROR: Duration is not an integer"
        return 1
    elif [[ ${duration} -lt 900 ]]; then
        duration=900
    elif [[ ${duration} -gt 43200 ]]; then
        duration=43200
    fi

    echoerr "INFO: Assuming role for session with duration: ${role_session_name} ${duration}"
    local role_output=$(aws sts assume-role \
        --role-arn ${role_arn} \
        --role-session-name ${role_session_name} \
        --duration-seconds ${duration})

    if [[ -z ${role_output-} ]]; then
        echoerr "ERROR: Can not assume role: ${role_name}"
        return 1
    fi

    export AWS_ASSUMED_ROLE_USER_ARN=$(echo ${role_output} | jq -r '.AssumedRoleUser.Arn')
    export AWS_CREDENTIALS_EXPIRATION=$(echo ${role_output} | jq -r '.Credentials.Expiration')

    export AWS_ACCESS_KEY_ID=$(echo ${role_output} | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo ${role_output} | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo ${role_output} | jq -r '.Credentials.SessionToken')

    echoerr "INFO: Assumed role of: ${AWS_ASSUMED_ROLE_USER_ARN}"

    unset role_output
}

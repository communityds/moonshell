#!/usr/bin/env bash
#
# Identity and Access Management
#

iam_access_keys () {
    local iam_user=$1

    [[ -z ${iam_user} ]] \
        && echoerr "ERROR: IAM username must be provided" \
        && return 1

    echoerr "INFO: Listing all access keys for '${iam_user}'"
    aws iam list-access-keys \
        --user-name ${iam_user} \
        --query "AccessKeyMetadata[].AccessKeyId" \
        --output text

    return $?
}

iam_user_arn () {
    local iam_user=$1

    [[ -z ${iam_user} ]] \
        && echoerr "ERROR: IAM username must be provided" \
        && return 1

    local user_arn=$(aws iam get-user \
        --user-name ${iam_user} \
        --query "User.Arn" \
        --output text 2>/dev/null)
}

iam_user_exists () {
    local iam_user=$1

    [[ -z ${iam_user} ]] \
        && echoerr "ERROR: IAM username must be provided" \
        && return 1

    aws iam get-user --user-name ${iam_user} &>/dev/null
    return $?
}

iam_users () {
    echoerr "INFO: Finding all user accounts"
    aws iam list-users \
        --query "Users[].UserName" \
        --output text
}


#!/usr/bin/env bash
#
# Identity and Access Management
#

_iam_test_group () {
    local iam_group=$1

    [[ -z ${iam_user} ]] \
        && echoerr "ERROR: IAM group must be provided" \
        && return 1

    if contains ${iam_group} $(iam_groups); then
        echoerr "INFO: Found group '${iam_group}'"
        return 0
    else
        echoerr "WARNING: Could not find group '${iam_group}'"
        return 1
    fi
}

_iam_test_user () {
    local iam_user=$1

    [[ -z ${iam_user} ]] \
        && echoerr "ERROR: IAM username must be provided" \
        && return 1

    if contains ${iam_user} $(iam_users); then
        echoerr "INFO: Found user '${iam_user}'"
        return 0
    else
        echoerr "WARNING: Could not find user '${iam_user}'"
        return 1
    fi
}

iam_access_key_create () {
    local iam_user=$1

    aws iam create-access-key \
        --user-name ${iam_user} \
        --query "AccessKey.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey}"
}

iam_access_key_list () {
    local iam_user=$1

    if ! _iam_test_user ${iam_user-}; then
        return 1
    fi

    echoerr "INFO: Listing all access keys for '${iam_user}'"
    aws iam list-access-keys \
        --user-name ${iam_user} \
        --query "AccessKeyMetadata[].AccessKeyId" \
        --output text

    return $?
}

iam_groups () {
    aws iam list-groups \
        --query "Groups[].GroupName" \
        --output text
}

iam_user_arn () {
    local iam_user=$1

    local user_arn=$(aws iam get-user \
        --user-name ${iam_user} \
        --query "User.Arn" \
        --output text 2>/dev/null)

    echo ${user_arn}
}

iam_user_create () {
    local iam_user=$1

    if _iam_test_user ${iam_user-}; then
        aws iam create-user --user-name ${iam_user}
    fi

    return $?
}

iam_user_exists () {
    local iam_user=$1

    _iam_test_user ${iam_user-}

    return $?
}

iam_user_group_add () {
    local iam_user=$1
    local iam_group=$2

    if _iam_test_group ${iam_group-}; then
        aws iam add-user-to-group \
            --group-name ${iam_group} \
            --user-name ${iam_user}
        return $?
    else
        return 1
    fi
}

iam_user_group_del () {
    local iam_user=$1
    local iam_group=$2

    if _iam_test_group ${iam_group-}; then
        aws iam remove-user-from-group \
            --group-name ${iam_group} \
            --user-name ${iam_user}
        return $?
    else
        return 1
    fi
}

iam_user_group_list () {
    local iam_user=$1

    aws iam list-groups-for-user \
        --user-name ${iam_user} \
        --query "Groups[].GroupName" \
        --output text

    return $?
}

iam_users () {
    aws iam list-users \
        --query "Users[].UserName" \
        --output text
}


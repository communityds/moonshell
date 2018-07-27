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
        return 0
    else
        return 1
    fi
}

_iam_test_user () {
    local iam_user=$1

    [[ -z ${iam_user} ]] \
        && echoerr "ERROR: IAM username must be provided" \
        && return 1

    if contains ${iam_user} $(iam_users); then
        return 0
    else
        return 1
    fi
}

iam_access_key_create () {
    local iam_user=$1

    if _iam_test_user ${iam_user-}; then
        echoerr "INFO: Creating API key and secret for '${iam_user}'"
        aws iam create-access-key \
            --user-name ${iam_user} \
            --query "AccessKey.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey}"
    fi
}

iam_access_key_delete () {
    local iam_user=$1
    local access_key=$2

    if ! _iam_test_user ${iam_user-}; then
        return 1
    elif [[ -z ${access_key-} ]]; then
        return 1
    fi

    aws iam delete-access-key \
        --user-name ${iam_user} \
        --access-key-id ${access_key}
}

iam_access_key_list () {
    local iam_user=$1

    if ! _iam_test_user ${iam_user-}; then
        return 1
    fi

    aws iam list-access-keys \
        --user-name ${iam_user} \
        --query "AccessKeyMetadata[].AccessKeyId" \
        --output text
}

iam_groups () {
    aws iam list-groups \
        --query "Groups[].GroupName" \
        --output text
}

iam_user_arn () {
    local iam_user=$1

    aws iam get-user \
        --user-name ${iam_user} \
        --query "User.Arn" \
        --output text
}

iam_user_create () {
    local iam_user=$1

    if ! _iam_test_user ${iam_user-}; then
        echoerr "INFO: Creating user '${iam_user}'"
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

iam_user_mfa_devices () {
    local iam_user=$1

    aws iam list-mfa-devices \
        --user-name ${iam_user} \
        --query 'MFADevices[].SerialNumber' \
        --output text
}

iam_user_policies () {
    local iam_user=$1

    aws iam list-attached-user-policies \
        --user-name ${iam_user} \
        --query 'AttachedPolicies[].PolicyArn' \
        --output text
}

iam_user_ssc () {
    local iam_user=$1

    aws iam list-service-specific-credentials \
        --user-name ${iam_user} \
        --query 'ServiceSpecificCredentials[].ServiceSpecificCredentialId' \
        --output text
}

iam_user_ssh_keys () {
    local iam_user=$1

    aws iam list-ssh-public-keys \
        --user-name ${iam_user} \
        --query 'SSHPublicKeys[].SSHPublicKeyId' \
        --output text
}

iam_users () {
    aws iam list-users \
        --query "Users[].UserName" \
        --output text
}


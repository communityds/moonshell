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

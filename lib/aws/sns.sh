#!/usr/bin/env bash
#
#
#

sns_post () {
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME \"SUBJECT\" \"MESSAGE\""
        return 1
    fi

    local stack_name="$1"
    local subject="$2"
    local message="$3"

    local notification_arn=$(stack_value_output ${stack_name} NotificationTopicArn)

    echoerr "INFO: Publishing to '${notification_arn}'"
    aws sns publish \
        --topic-arn ${notification_arn} \
        --region ${AWS_REGION} \
        --subject "${subject}" \
        --message "$(printf ${message} | head -c256k)"
}

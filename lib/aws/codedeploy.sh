#!/usr/bin/env bash
#
#
#

codedeploy_overlay () {
    # This has to be a function, and not a script, because the invocation of
    # `overlay_dir` inside a script would only be usable in the sub-process
    # that spawned it.
    local domain_name=${HOSTNAME#*.}
    local stack_name=${domain_name%%.*}

    local deployment_uuid=$(aws deploy get-deployment-group \
        --region ${AWS_REGION} \
        --deployment-group-name ${stack_name} \
        --application-name ${stack_name} \
        --query "deploymentGroupInfo.deploymentGroupId" \
        --output text)

    local deployment_base="/opt/codedeploy-agent/deployment-root/${deployment_uuid}"

    local deployment_id=$(aws deploy list-deployments \
        --region ${AWS_REGION} \
        --application-name ${stack_name} \
        --deployment-group-name ${stack_name} \
        --include-only-statuses Succeeded \
        --max-items 1 \
        | jq -r '.deployments[0]')

    if [[ ! -d "${deployment_base}/${deployment_id}" ]]; then
        echoerr "WARNING: Preferred deployment path does not exist: ${deployment_base}/${deployment_id}"
        local test_deployment_id=$(ls -t1 ${deployment_base} | head -n1)

        if [[ -z ${test_deployment_id-} ]]; then
            echoerr "ERROR: Codedeploy has not succeeded"
            return 1
        else
            echoerr "INFO: Found alternate deployment: ${test_deployment_id}"
            local deployment_path="${deployment_base}/${test_deployment_id}/deployment-archive"
        fi
    else
        echoerr "INFO: Found preferred deployment: ${deployment_id}"
        local deployment_path="${deployment_base}/${deployment_id}/deployment-archive"
    fi

    if [[ ! -d ${deployment_path} ]]; then
        echoerr "ERROR: Deployment has not completed"
        return 1
    else
        echoerr "INFO: Overlaying deployment path: ${deployment_path}"
        overlay_dir ${deployment_path}
    fi
}


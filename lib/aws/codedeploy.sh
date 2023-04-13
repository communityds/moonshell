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

    local deployment_path

    local -a deployment_current=($(find /opt/codedeploy-agent/ -type l -name current 2>/dev/null))

    if [[ -z ${deployment_current-} ]] || [[ ${#deployment_current[@]} -gt 1 ]]; then
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
                deployment_path="${deployment_base}/${test_deployment_id}/deployment-archive"
            fi
        else
            echoerr "INFO: Found preferred deployment: ${deployment_id}"
            deployment_path="${deployment_base}/${deployment_id}/deployment-archive"
        fi
    else
        deployment_path=${deployment_current}
    fi

    if [[ ! -d ${deployment_path} ]]; then
        echoerr "ERROR: Deployment has not completed"
        return 1
    else
        echoerr "INFO: Overlaying deployment path: ${deployment_path}"
        overlay_dir ${deployment_path}
    fi
}


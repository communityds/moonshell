#!/usr/bin/env bash
#
# STACK FUNCTIONS
#
_stack_codedeploy_changed_files () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} GIT_COMMIT GIT_COMMIT"
        return 1
    fi
    local commit_1="$1"
    local commit_2="$2"

    git diff-tree --no-commit-id --name-only -r ${commit_1} ${commit_2} \
        | grep -E "^codedeploy/" \
        || true
}

stack_id () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        --query "Stacks[].StackId" \
        --output text
}

stack_list_app () {
    # List all stacks of the same type as the app you are administering
    aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --query "Stacks[?contains (StackName, '${APP_NAME}')].StackName" \
        --output text
    return $?
}

stack_list_all () {
    aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        | jq -r '.Stacks[].StackName' \
        | sort
}

stack_list_all_parents () {
    aws cloudformation list-stacks \
        --region ${AWS_REGION} \
        --stack-status-filter UPDATE_COMPLETE CREATE_COMPLETE ROLLBACK_COMPLETE \
        --query "StackSummaries[?not_null(TemplateDescription)].StackName" \
        | jq -r '.[]' \
        | sort
}

stack_list_nested () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    local stack_id=$(stack_id ${stack_name})
    local -a stack_status_ok=($(stack_status_ok))

    local nested_stacks=($(aws cloudformation list-stacks \
        --region ${AWS_REGION} \
        --stack-status-filter ${stack_status_ok[@]} \
        --query "StackSummaries[?ParentId=='${stack_id}'].StackName" \
        --output text))

    if [[ -z ${nested_stacks-} ]]; then
        echoerr "WARNING: No nested stacks found "
        return 0
    else
        echo ${nested_stacks[@]}
    fi
}

stack_list_others () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    # List every stack in an account, except the one we are administering..
    local stack_name="$1"

    local -a all_stacks=($(stack_list_all))

    local stack
    for stack in ${all_stacks[@]/^$stack_name$}; do
        echo "${stack}"
    done
}

stack_list_output () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        | jq -r '.Stacks[].Outputs[].OutputKey' \
        | sort

    pipe_failure ${PIPESTATUS[@]}
}

stack_list_parameter () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        | jq -r '.Stacks[].Parameters[].ParameterKey' \
        | sort

    pipe_failure ${PIPESTATUS[@]}
}

stack_name () {
    export STACK_NAME="${APP_NAME}-${ENVIRONMENT}"
}

stack_name_from_vpc_id () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} VPC_ID"
        return 1
    fi
    local vpc_id="$1"

    local stack_name=$(aws ec2 describe-vpcs \
        --region ${AWS_REGION} \
        --filters Name=vpc-id,Values=${vpc_id} \
        --query "Vpcs[].Tags[?Key=='aws:cloudformation:stack-name'].Value" \
        --output text)

    if [[ ! ${stack_name-} ]]; then
        echoerr "ERROR: Could not resolve 'aws:cloudformation:stack-name' tag key from vpc: ${vpc_id}"
        return 1
    else
        echo ${stack_name}
        return 0
    fi
}

stack_outputs () {
    local stack_name=$1

    aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        --query 'sort_by(Stacks[].Outputs[], &OutputKey)[]'
}

stack_parameter_file () {
    if [[ -z ${ENVIRONMENT-} ]]; then
        echoerr "FATAL: Unset variable: ENVIRONMENT"
        return 255
    fi

    export STACK_PARAMETER_FILE="moonshell/${ENVIRONMENT}.sh"

    if [[ ! -f "${STACK_PARAMETER_FILE}" ]]; then
        echoerr "ERROR: Can not find parameter file: ${STACK_PARAMETER_FILE}"
        return 1
    fi
}

stack_parameter_file_parse () {
    local param_file=$1
    local param_var=$2

    if ! typeset -Ap ${param_var} >&/dev/null; then
        echoerr "ERROR: '${param_var}' is not an associative array"
        return 1
    fi

    local line param_key param_value
    while read line; do
        if [[ ${line} =~ ^[a-zA-Z0-9_]+\= ]]; then
            param_key=${line%%=*}
            param_value=${line#*=}
            eval ${param_var}[${param_key}]=${param_value}
        fi
    done <${param_file}
}

stack_parameter_set () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME PARAM_KEY PARAM_VALUE"
        return 1
    fi
    local stack_name="$1"
    local parameter_key="$2"
    local parameter_value="${3-}"

    local parameters=($(aws cloudformation get-template-summary \
        --region ${AWS_REGION} \
        --stack-name ${stack_name}  \
        | jq -r '.Parameters[].ParameterKey'))

    if ! contains ${parameter_key} ${parameters[@]}; then
        echoerr "ERROR: Can not update non-existant parameter: ${parameter_key}"
        return 1
    fi

    local parameter parameter_json
    for parameter in ${parameters[@]}; do
        if [[ ${parameter} == ${parameter_key} ]]; then
            parameter_json+=",{\"ParameterKey\":\"${parameter}\",\"ParameterValue\":\"${parameter_value-}\"}"
        else
            parameter_json+=",{\"ParameterKey\":\"${parameter}\",\"UsePreviousValue\":true}"
        fi
    done

    echoerr "INFO: Updating '${stack_name}'"
    aws cloudformation update-stack \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        --parameters "[${parameter_json#,}]" \
        --use-previous-template \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        >/dev/null \
        && echoerr "INFO: Waiting for update to complete" \
        && aws cloudformation wait stack-update-complete \
            --region ${AWS_REGION} \
            --stack-name ${stack_name}

    return $?
}

stack_parameters () {
    local stack_name=$1

    aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        --query 'sort_by(Stacks[].Parameters[], &ParameterKey)[]'
}

stack_resource_id () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE"
        return 1
    fi
    local stack_name="$1"
    local resource="$2"

    local resource_id=$(aws cloudformation describe-stack-resource \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        --logical-resource-id ${resource} \
        --query "StackResourceDetail.PhysicalResourceId" \
        --output text)

    if [[ ${resource_id-} ]]; then
        echo ${resource_id}
        return 0
    else
        echoerr "ERROR: Could not resolve resource: ${resource}"
        return 1
    fi
}

stack_resource_type_id () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE_TYPE"
        return 1
    fi
    local stack_name="$1"
    local resource_type="$2"

    local -a resource_ids=($(aws cloudformation list-stack-resources \
        --region ${AWS_REGION} \
        --stack-name "${stack_name}" \
        --query "StackResourceSummaries[?ResourceType=='${resource_type}'].PhysicalResourceId" \
        --output text))

    if [[ -z ${resource_ids[@]-} ]]; then
        echoerr "WARNING: No resources of type found: ${resource_type}"
        return 1
    else
        echo ${resource_ids[@]}
        return 0
    fi
}

stack_resource_type_name () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE_TYPE"
        return 1
    fi
    local stack_name="$1"
    local resource_type="$2"

    local -a resource_names=($(aws cloudformation list-stack-resources \
        --region ${AWS_REGION} \
        --stack-name "${stack_name}" \
        --query "StackResourceSummaries[?ResourceType=='${resource_type}'].LogicalResourceId" \
        --output text))

    if [[ -z ${resource_names[@]-} ]]; then
        echoerr "WARNING: No resources of type found: ${resource_type}"
        return 1
    else
        echo ${resource_names[@]}
        return 0
    fi
}

stack_status () {
    [[ $# -lt 1 ]] \
        && echoerr "Usage: ${FUNCNAME[0]} STACK_NAME" \
        && return 1

    local stack_name=${1-}

    local status=$(aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        --query "Stacks[].StackStatus" \
        --output text \
        2>/dev/null)

    if [[ -z ${status-} ]]; then
        echo NULL
        return 1
    fi

    echo ${status}
}

stack_status_from_id () {
    [[ $# -lt 1 ]] \
        && echoerr "Usage: ${FUNCNAME[0]} STACK_ID" \
        && return 1

    local stack_id=$1

    aws cloudformation list-stacks \
        --region ${AWS_REGION} \
        --query "StackSummaries[?StackId=='${stack_id}'].StackStatus" \
        --output text
}

stack_status_ok () {
    local -a status_complete=(
        UPDATE_COMPLETE
        CREATE_COMPLETE
        ROLLBACK_COMPLETE
        UPDATE_ROLLBACK_COMPLETE
    )
    echo ${status_complete[@]}
}

stack_template_bucket () {
    if [[ -z ${STACK_TEMPLATE_BUCKET-} ]]; then
        echoerr "FATAL: Undefined variable: STACK_TEMPLATE_BUCKET"
        return 1
    fi
}

stack_template_bucket_scheme () {
    if [[ -z ${STACK_TEMPLATE_BUCKET_SCHEME-} ]]; then
        export STACK_TEMPLATE_BUCKET_SCHEME="https://"
    fi

    if [[ ! ${STACK_TEMPLATE_BUCKET_SCHEME} =~ ^(https|file)://$ ]]; then
        echoerr "ERROR: Unsupported scheme: ${STACK_TEMPLATE_BUCKET_SCHEME}"
        return 1
    fi
}

stack_template_file () {
    if [[ -z ${STACK_TEMPLATE_FILE-} ]]; then
        export STACK_TEMPLATE_FILE="moonshell/templates/template.yml"
    fi

    if [[ ! -f "${STACK_TEMPLATE_FILE}" ]]; then
        echoerr "ERROR: Can not find template file: ${STACK_TEMPLATE_FILE}"
        return 1
    fi
}

stack_template_upload () {
    stack_template_bucket_scheme
    stack_template_bucket
    stack_template_file

    local template_dir="$(dirname ${STACK_TEMPLATE_FILE})"
    if [[ -z ${template_dir-} ]] || [[ ! -d ${template_dir} ]]; then
        echoerr "FATAL: Can not resolve the directory from: ${STACK_TEMPLATE_FILE}"
        return 255
    fi

    echoerr "INFO: Uploading templates from: ${template_dir}"
    aws s3 sync \
        --delete \
        ${template_dir}/ \
        s3://${STACK_TEMPLATE_BUCKET}/${STACK_NAME}/
}

_stack_update_changed_files () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} GIT_COMMIT GIT_COMMIT"
        return 1
    fi
    local commit_1="$1"
    local commit_2="$2"

    git diff-tree --no-commit-id --name-only -r ${commit_1} ${commit_2} \
        | grep -E "^moonshell/(${ENVIRONMENT}.sh|moonshell.sh|templates/)" \
        || true
}

stack_value () {
    if [[ $# -lt 3 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE PARAM"
        return 1
    fi
    local stack_name="$1"
    local resource="$2"
    local param="$3"

    local resource_id=$(aws cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${stack_name} \
        --query "Stacks[].${param}s[?${param}Key=='${resource}'].${param}Value" \
        --output text)

    if [[ ${resource_id-} ]]; then
        echo "${resource_id}"
        return 0
    else
        echoerr "ERROR: Could not resolve ${param} resource: ${resource}"
        return 1
    fi
}

stack_value_input () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE"
        return 1
    fi
    local stack_name="$1"
    local resource="$2"

    stack_value "${stack_name}" "${resource}" Input
    return $?
}

stack_value_parameter () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE"
        return 1
    fi
    local stack_name="$1"
    local resource="$2"

    stack_value "${stack_name}" "${resource}" Parameter
    return $?
}

stack_value_output () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE"
        return 1
    fi
    local stack_name="$1"
    local resource="$2"

    stack_value "${stack_name}" "${resource}" Output
    return $?
}


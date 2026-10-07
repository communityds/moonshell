#!/usr/bin/env bash
#
# RDS FUNCTIONS
#
rds_dump_db () {
    if [[ $# -lt 3 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME DATABASE OUT_FILE [OPTIONS]"
        return 1
    fi
    local stack_name="$1"
    local database="$2"
    local out_file="$3"
    local options="${4-}"

    local instance=$(rds_instance_select ${stack_name})
    [[ -z ${instance-} ]] && return 1

    local engine=$(rds_engine_type ${stack_name} ${instance})
    [[ -z ${engine-} ]] && return 1

    rds_${engine}_dump_db ${stack_name} ${database} "${out_file}" "${options-}"
    return $?
}

rds_engine_type () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME RESOURCE_NAME"
        return 1
    fi
    local stack_name="$1"
    local resource_name="$2"

    local engine=$(aws rds describe-db-instances \
        --region ${AWS_REGION} \
        --db-instance-identifier ${resource_name} \
        | jq -r '.DBInstances[].Engine')

    [[ -z ${engine-} ]] && return 1

    # We only support MySQL and PostgreSQL
    case ${engine} in
        mysql) echo "mysql";;
        mariadb) echo "mysql";;
        postgres) echo "postgres";;
        *)
            echoerr "ERROR: Unsupported engine type: ${engine}"
            return 1
        ;;
    esac
}

rds_instance_select () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME [REPLICA]"
        return 1
    fi
    local stack_name="$1"
    local replica="${2-}"

    local instance replica
    local -a instances=($(rds_stack_resources ${stack_name}))

    if [[ ${instances[@]-} ]]; then
        if [[ ${#instances[@]} == 1 ]]; then
            echo ${instances}
            return 0
        else
            for instance in ${instances[@]}; do
                db_instance=$(aws rds describe-db-instances \
                    --region ${AWS_REGION} \
                    --db-instance-identifier ${instance} \
                    | jq '.DBInstances[]')

                if [[ ${replica-} ]]; then
                    has_source=$(echo ${db_instance} \
                        | jq -r '.ReadReplicaSourceDBInstanceIdentifier // ""')

                    if [[ ${has_source-} ]]; then
                        echo ${instance}
                        return 0
                    fi
                else
                    has_replica=$(echo ${db_instance} \
                        | jq -r '.ReadReplicaDBInstanceIdentifiers[] // ""')

                    if [[ ${has_replica-} ]]; then
                        echo ${instance}
                        return 0
                    fi
                fi
            done

            # If there are multiple DBs in a stack then we need user help.
            instance=$(choose ${instances[@]})
            echo ${instance}
            return 0
        fi
    else
        echoerr "ERROR: No RDS instances found in stack: ${stack_name}"
        return 1
    fi
}

rds_log_download () {
    if [[ $# -lt 3 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME LOG_FILE DUMP_FILE [REPLICA]"
        return 1
    fi
    local stack_name="$1"
    local log_file="$2"
    local dump_file="$3"
    local replica="${4-}"

    local instance=$(rds_instance_select ${stack_name} ${replica-})
    [[ ${instance-} ]] \
        && echoerr "INFO: Found DB instance: ${instance}" \
        || return 1

    echoerr "INFO: Discovering log files"
    log_file_names=($(aws rds describe-db-log-files \
        --region ${AWS_REGION} \
        --db-instance-identifier ${instance} \
        | jq -r ".DescribeDBLogFiles | sort_by(.LastWritten) | .[] | select(.LogFileName | startswith(\"${log_file}\")) | .LogFileName"))

    if [[ -z ${log_file_names-} ]]; then
        echoerr "ERROR: No log files found matching: ${log_file}"
        return 1
    fi

    truncate -s0 ${dump_file}

    for log_file_name in ${log_file_names[@]}; do
        echoerr "INFO: Downloading log file: ${log_file_name}"
        aws rds download-db-log-file-portion \
            --region ${AWS_REGION} \
            --db-instance-identifier ${instance} \
            --starting-token 0 \
            --log-file-name ${log_file_name} \
            --output text \
            >> ${dump_file}
    done

    return $?
}

rds_log_files () {
    if [[ $# -lt 1 ]]; then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi

    local stack_name="$1"

    local instance=$(rds_instance_select ${stack_name})
    if [[ ${instance-} ]]; then
        echoerr "INFO: Found DB instance: ${instance}"
    else
        return 1
    fi

    aws rds describe-db-log-files \
        --region ${AWS_REGION} \
        --db-instance-identifier ${instance} \
        | jq -r '.DescribeDBLogFiles | sort_by(.LastWritten) | .[].LogFileName'

    return $?
}

rds_slowlog () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME DUMP_FILE [INDEX]"
        return 1
    fi
    local stack_name="$1"
    local dump_file="$2"
    local index="${3-}"

    [[ ${index-} ]] \
        && local suffix=".${index}" \
        || local suffix=""

    local instance=$(rds_instance_select ${stack_name})
    [[ ${instance-} ]] \
        && echoerr "INFO: Found DB instance: ${instance}" \
        || return 1

    # There are other slowquery.log files available, but there is no apparent
    # way to enumerate the logs available, so we default to the first, and most
    # current, one.
    aws rds download-db-log-file-portion \
        --region ${AWS_REGION} \
        --db-instance-identifier ${instance} \
        --starting-token 0 \
        --log-file-name slowquery/mysql-slowquery.log${suffix-} \
        --output text \
        > ${dump_file}

    return $?
}

rds_snapshot_create () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME SNAPSHOT_ID"
        return 1
    fi
    local stack_name="$1"
    local snapshot_id="$2"

    local instance=$(rds_instance_select ${stack_name})
    [[ ${instance-} ]] \
        && echoerr "INFO: Found DB instance '${instance}'" \
        || return 1

    echoerr "INFO: Creating DB snapshot"
    aws rds create-db-snapshot \
        --region ${AWS_REGION} \
        --db-instance-identifier ${instance} \
        --db-snapshot-identifier ${snapshot_id} \

    echoerr "INFO: Waiting for snapshot to complete"
    aws rds wait db-snapshot-completed \
        --region ${AWS_REGION} \
        --db-snapshot-identifier ${snapshot_id}

    return $?
}

rds_snapshot_delete () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} SNAPSHOT_ID"
        return 1
    fi
    local snapshot_id="$1"

    echoerr "INFO: Deleting DB snapshot"
    aws rds delete-db-snapshot \
        --region ${AWS_REGION} \
        --db-snapshot-identifier ${snapshot_id}

    return $?
}

rds_snapshot_list () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    local instance=$(rds_instance_select ${stack_name})
    [[ ${instance-} ]] \
        && echoerr "INFO: Found DB instance '${instance}'" \
        || return 1

    echoerr "INFO: Finding snapshots for DB instance"
    local snapshots=($(aws rds describe-db-snapshots \
        --region ${AWS_REGION} \
        | jq -r ".DBSnapshots[] | selectd(.DBInstanceIdentifier == \"${instance}\") | .DBSnapshotIdentifier"))

    [[ -z ${snapshots[@]-} ]] \
        && echoerr "INFO: No snapshots found for DB instance: ${instance}" \
        && return 1

    for snapshot in ${snapshots[@]}; do
        echo "${snapshot}"
    done

    return $?
}

rds_stack_resources () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    local -a stack_status_ok=($(stack_status_ok))

    local stack_id=$(aws cloudformation list-stacks \
        --region ${AWS_REGION} \
        --stack-status-filter ${stack_status_ok[@]} \
        | jq -r ".StackSummaries[] | select(.StackName == \"${stack_name}\") | .StackId")

    local nested_stacks=($(aws cloudformation list-stacks \
        --region ${AWS_REGION} \
        --stack-status-filter ${stack_status_ok[@]} \
        | jq -r ".StackSummaries[] | select(.ParentId == \"${stack_id}\") | .StackName"))

    if [[ ${#nested_stacks[@]} -gt 0 ]]; then
        local nested_stack
        local -a db_instance_test

        for nested_stack in ${stack_name} ${nested_stacks[@]}; do
            # squelch 'warning' output from testing a stack which does not have a DBInstance
            db_instance_test=($(stack_resource_type_id ${nested_stack} "AWS::RDS::DBInstance" 2>/dev/null))
            if [[ ${#db_instance_test[@]} -gt 0 ]]; then
                echo ${db_instance_test[@]}
                return 0
            fi
        done
        return 1
    else
        stack_resource_type_id ${stack_name} "AWS::RDS::DBInstance"
        return $?
    fi
}

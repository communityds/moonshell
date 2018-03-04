#!/usr/bin/env bash
#
# RDS FUNCTIONS
#
rds_dump_db () {
    # Dump a named ${database} to the defined ${out_file}
    local stack_name=$1
    local database=$2
    local out_file=$3

    local instance=$(rds_instance_select ${stack_name})
    [[ -z ${instance-} ]] && return 1

    local engine=$(rds_engine_type ${stack_name} ${instance})
    [[ -z ${engine-} ]] && return 1

    rds_${engine}_dump_db ${stack_name} ${database} ${out_file}
    return $?
}

rds_engine_type () {
    # Query RDS resource for DB engine type and return result as a string
    local stack_name=$1
    local resource_name=$2

    local engine=$(aws rds describe-db-instances \
        --region ${AWS_REGION} \
        --db-instance-identifier ${resource_name} \
        --query "DBInstances[].Engine" \
        --output text)
    [[ -z ${engine-} ]] && return 1

    # We only support MySQL and PostgreSQL
    case ${engine} in
        mysql) echo "mysql";;
        mariadb) echo "mysql";;
        postgres) echo "postgres";;
        *)
            echoerr "ERROR: Unsupported engine type '${engine}'"
            return 1
        ;;
    esac
}

rds_instance_select () {
    # If there are multiple RDS resources, prompt for selection and return
    # selection as a string
    local stack_name=$1
    local i db
    local -a instances=($(rds_stack_resources ${stack_name}))

    if [[ ${instances[@]-} ]]; then
        if [[ ${#instances[@]} == 1 ]]; then
            echo ${instances}
            return 0
        else
            echoerr "Select a DB instance:"
            choose ${instances[@]}
            return $?
        fi
    else
        echoerr "ERROR: No RDS instances found in stack '${stack_name}'"
        return 1
    fi
}

rds_list_dbs () {
    # list all databases hosted on the RDS instance.
    local stack_name=$1

    local instance=$(rds_instance_select ${stack_name})
    [[ -z ${instance-} ]] && return 1

    local engine=$(rds_engine_type ${stack_name} ${instance})
    [[ -z ${engine-} ]] && return 1

    rds_${engine}_list_dbs ${stack_name} ${instance}
    return $?
}

rds_mysql_dump_db () {
    local stack_name=$1
    local database=$2
    local out_file=$3

    local last_line
    local mysql_opts="--complete-insert --disable-keys --single-transaction"

    echoerr "INFO: Dumping ${database} to ${out_file}"

    bastion_exec_utility ${stack_name} \
        "'mysqldump ${mysql_opts} ${database} | gzip -c'" \
        ${out_file}

    last_line="$(zcat ${out_file} | tail -1 | sed -e 's/^-- //')"
    if [[ "${last_line}" =~ "Dump completed" ]]; then
        echoerr "INFO: ${last_line}"
        return 0
    else
        echoerr "ERROR: mysqldump failed to complete successfully"
        return 1
    fi
}

rds_mysql_list_dbs () {
    stack_name=$1
    instance=$2

    bastion_exec_utility ${stack_name} \
        "'mysql -BNe \"SHOW DATABASES;\"'"
}

rds_mysql_restore_db () {
    local stack_name=$1
    local database=$2
    local in_file=$3

    local upload_file=$(basename ${in_file})
    local mysql_opts=" "

    echoerr "INFO: Uploading file to $(bastion):/tmp/"
    bastion_upload_file ${stack_name} ${in_file}

    echoerr "INFO: Recreating database: ${database}"
    bastion_exec_utility ${stack_name} \
        "'mysql -e \"DROP DATABASE IF EXISTS ${database}; CREATE DATABASE ${database};\"'"

    echoerr "INFO: Restoring database from /tmp/${upload_file}"
    bastion_exec_utility ${stack_name} \
        "'zcat /tmp/${upload_file} \
            | mysql ${mysql_opts} ${database}; \
            rm -f /tmp/${upload_file}'"

    echoerr "INFO: Removing uploaded files"
    bastion_exec "rm -f /tmp/${upload_file}"
    bastion_exec_utility ${stack_name} "rm -f /tmp/${upload_file}"
}

rds_postgres_dump_all () {
    # Postgres in AWS land uses SuperUser™. This user actually isn't..
    # SuperUser™'s privileges are reduced to prevent n00bs from screwing with
    # low level pgsql shiz. As such, we can not use pg_dumpall.
    #
    # TODO: programatically dump all databases one by one..
    echoerr "WARNING: Dumping all databases is currently unsupported."
    return 1
}

rds_postgres_dump_db () {
    # To dump a postgres database SuperUser™ must have the database granted to,
    # and revoked from, it. The database is dumped as plain text and not a
    # compressed or other format because we need to sed out some things that
    # SuperUser™ doesn't have access to do, like add a fucking comment...
    local stack_name=$1
    local database=$2
    local out_file=$3
    local pg_opts="--no-privileges --if-exists --clean --no-owner"

    rds_postgres_grant ${stack_name} ${database}

    echoerr "INFO: Dumping ${database} to ${out_file}"

    bastion_exec_utility ${stack_name} \
        "'pg_dump -Fp ${pg_opts} ${database}'" \
        ${out_file}

    if [[ $(uname) =~ ^Darwin$ ]]; then
        sed -i -e '/^COMMENT ON EXTENSION plpgsql IS/d' ${out_file}
        sed -i -e '/^COMMENT ON EXTENSION citext IS/d' ${out_file}
        sed -i -e '/^COMMENT ON EXTENSION "uuid-ossp" IS/d' ${out_file}
    else
        sed -i \
            -e '/^COMMENT ON EXTENSION plpgsql IS/d' \
            -e '/^COMMENT ON EXTENSION citext IS/d' \
            -e '/^COMMENT ON EXTENSION "uuid-ossp" IS/d' \
            ${out_file}
    fi

    # Because we had to sed the sql, we couldn't pipe directly to gzip, so we
    # must do shoddy things to make the system work. AWS have been removed from
    # my Christmas card list..
    local janky_file=$(echo -n ${out_file} | sed -e 's/\.gz$//')
    mv ${out_file} ${janky_file} && gzip ${janky_file}

    rds_postgres_revoke ${stack_name} ${database}
}

rds_postgres_grant () {
    # Grant a database to SuperUser™
    local stack_name=$1
    local database=$2
    echoerr "INFO: Granting ownership of ${database} to postgres"
    bastion_exec_utility ${stack_name} \
        "'psql -d ${database} -c \"
            GRANT ${database}_app TO postgres;
            GRANT ${database}_client TO postgres;
        \" || true'"
}

rds_postgres_list_dbs () {
    local stack_name=$1

    local databases=($(bastion_exec_utility ${stack_name} \
        "'psql -tAc \"select datname from pg_DATABASE;\"'"))
    [[ -z ${databases[@]-} ]] && return 1

    for database in ${databases[@]-}; do
        if ! contains ${database} ${POSTGRES_IGNORED_DBS[@]-}; then
            echo ${database}
        fi
    done
}

rds_postgres_restore_all () {
    # see rds_postgres_dump_all
    echoerr "WARNING: Restoration of all databases is currently unsupported."
    return 1
}

rds_postgres_restore_db () {
    # In restoring a database permissions will not be properly set. If you
    # restore a postgres db with this function, you will have to fix up
    # permissions after restoration. Once again GRANT and REVOKE must be
    # explicitly called.
    local stack_name=$1
    local database=$2
    local in_file=$3

    local upload_file=$(basename ${in_file})
    local bastion=$(bastion)
    local pg_opts="--single-transaction --echo-errors"

    rds_postgres_grant ${stack_name} ${database}

    echoerr "INFO: Uploading ${in_file} to ${bastion}"
    bastion_upload_file ${stack_name} ${in_file}

    echoerr "INFO: Restoring DB to ${database}:"
    bastion_exec_utility ${stack_name} \
        "'zcat /tmp/${upload_file} | psql ${pg_opts} -d ${database}'"

    rds_postgres_revoke ${stack_name} ${database}

    echoerr "INFO: Removing uploaded files"
    bastion_exec "rm -f /tmp/${upload_file}"
    bastion_exec_utility ${stack_name} "rm -f /tmp/${upload_file}"

    return $?
}

rds_postgres_revoke () {
    # Revoke permissions of ${database} from SuperUser™
    local stack_name=$1
    local database=$2
    echoerr "INFO: Revoking ownership of ${database} from postgres"
    bastion_exec_utility ${stack_name} \
        "'psql -d ${database} -c \"
            REVOKE ${database}_app FROM postgres;
            REVOKE ${database}_client FROM postgres;
        \" || true'"
}

rds_restore_db () {
    # Restore a named ${database} from a defined ${in_file}
    local stack_name=$1
    local database=$2
    local in_file=$3

    echoerr "INFO: Setting variables"

    local instance=$(rds_instance_select ${stack_name})
    [[ -z ${instance-} ]] && return 1

    local engine=$(rds_engine_type ${stack_name} ${instance})
    [[ -z ${engine-} ]] && return 1

    rds_${engine}_restore_db ${stack_name} ${database} ${in_file}
    return $?
}

rds_snapshot_create () {
    local stack_name=$1
    local snapshot_id=$2

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
    local snapshot_id=$1

    echoerr "INFO: Deleting DB snapshot"
    aws rds delete-db-snapshot \
        --region ${AWS_REGION} \
        --db-snapshot-identifier ${snapshot_id}

    return $?
}

rds_snapshot_list () {
    local stack_name=$1

    local instance=$(rds_instance_select ${stack_name})
    [[ ${instance-} ]] \
        && echoerr "INFO: Found DB instance '${instance}'" \
        || return 1

    echoerr "INFO: Finding snapshots for DB instance"
    local snapshots=($(aws rds describe-db-snapshots \
        --region ${AWS_REGION} \
        --query "DBSnapshots[?DBInstanceIdentifier=='${instance}'].DBSnapshotIdentifier" \
        --output text))
    [[ -z ${snapshots[@]-} ]] \
        && echoerr "INFO: No snapshots found for DB instance '${instance}'" \
        && return 1

    for snapshot in ${snapshots[@]}; do
        echo "${snapshot}"
    done

    return $?
}

rds_stack_resources () {
    # Enumerate all RDS resources in the stack and return an array
    local stack_name=$1
    stack_resource_type ${stack_name} "AWS::RDS::DBInstance"
    return $?
}

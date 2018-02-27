#!/usr/bin/env bash
#
# ROUTE53 FUNCTIONS
#
route53_change_resource_records () {
    local hosted_zone_id=$1
    local action=$2
    local resource_record="$3"

    [[ ! ${action} =~ ^(UPSERT|DELETE)$ ]] \
        && echoerr "ERROR: Unsupported action '${action}'" \
        && return 1

    [[ $# -gt 3 ]] \
        && echoerr "ERROR: Too many arguments, did you send and array and not a string?" \
        && return 1

    echoerr "INFO: Executing ${action} on ${hosted_zone_id}"
    local change_id=$(aws route53 change-resource-record-sets \
        --region ${AWS_REGION} \
        --hosted-zone-id ${hosted_zone_id} \
        --change-batch "{\"Changes\": [{
        \"Action\": \"${action}\",
        \"ResourceRecordSet\":
            ${resource_record}
        }]}" \
        --query "ChangeInfo.Id" \
        --output text)

    [[ -z ${change_id-} ]] \
        && echoerr "ERROR: Failed to submit change" \
        && return 1

    echoerr "INFO: Waiting for ${change_id} to complete..."
    aws route53 wait resource-record-sets-changed \
        --region ${AWS_REGION} \
        --id ${change_id}
    return $?

}

route53_delete_records () {
    # Iterate over an array of ${resources[@]} and delete each entry from the
    # ${hosted_zone_id}
    [[ $# -lt 2 ]] \
        && echoerr "ERROR: At least two arguments are required" \
        && return 1

    local hosted_zone_id=$1
    shift
    local resources=(${@-})

    for resource in ${resources[@]}; do
        # The resource_record is a JSON hash, so quote that shit!
        local resource_record="$(route53_get_resource_record ${hosted_zone_id} ${resource})"
        if [[ ${resource_record-} ]]; then
            echoerr "INFO: Deleting resource record '${resource}' from ${hosted_zone_id}"
            route53_delete_record_set ${hosted_zone_id} "${resource_record}"
        else
            echoerr "WARNING: Skipping ${resource}"
        fi
    done
}

route53_delete_record_set () {
    # Delete an individual record from Route53. The resource_record must be an
    # appropriate JSON hash for the --change-batch function
    local hosted_zone_id=$1
    [[ $# -gt 2 ]] \
        && echoerr "ERROR: You parsed in an array, not a string for \$2" \
        && return 1 \
        || local resource_record="$2"

    echoerr "INFO: Deleting resource from ${hosted_zone_id}"
    route53_change_resource_records ${hosted_zone_id} DELETE ${resource_record}
    return $?
}

route53_external_hosted_zone_name () {
    local stack_name=$1

    stack_value_output ${stack_name} "ExternalRoute53HostedZoneName"
    return $?
}

route53_external_hosted_zone_id () {
    local stack_name=$1

    local hosted_zone_name=$(route53_external_hosted_zone_name ${stack_name})
    [[ -z ${hosted_zone_name-} ]] \
        && echoerr "ERROR: Could not find hosted_zone_name" \
        && return 1

    local hosted_zone_id=$(aws route53 list-hosted-zones-by-name \
        --query "HostedZones[?Name=='${hosted_zone_name}'].Id" \
        --output text \
        | grep -Eo '(\w+)$')

    if [[ -z ${hosted_zone_id-} ]]; then
        echoerr "ERROR: could not find hosted_zone_id from ${hosted_zone_name}"
        return 1
    else
        echo ${hosted_zone_id}
        return 0
    fi
}

route53_fqdn_from_host () {
    # Find the FQDN in a hosted_zone from just the host's name. This is for
    # finding that "logger" actually resolves to "logger.core-production.local"
    local hosted_zone_id=$1
    local host=$2

    aws route53 list-resource-record-sets \
        --region ${AWS_REGION} \
        --hosted-zone-id ${hosted_zone_id} \
        --query "ResourceRecordSets[?contains (Name, '${host}')].Name" \
        --output text
    return $?
}

route53_get_resource_record () {
    if ! $(which jq &>/dev/null); then
        echoerr "INFO: Attempting to install jq"
        sudo yum -y install jq
        if [[ $? -ne 0 ]]; then
            echoerr "ERROR: Failed to install jq"
            return 1
        fi
    fi
    # From a ${resource} record in the ${hosted_zone_id}, output JSON
    local hosted_zone_id=$1
    local resource=$2

    # The resource must be properly fully qualified
    [[ ! ${resource} =~ \.$ ]] && resource="${resource}."

    local resource_record="$(aws route53 list-resource-record-sets \
        --region ${AWS_REGION} \
        --hosted-zone-id ${hosted_zone_id} \
        --query "ResourceRecordSets[?Name=='${resource}']" \
        | jq -c '.[]')"

    if [[ -z ${resource_record-} ]]; then
        echoerr "WARNING: No record found for resource '${resource}'"
        return 1
    else
        echo "${resource_record}"
        return 0
    fi
}

route53_id_from_zone_name () {
    local hosted_zone_name=$1

    # hosted_zone_name must be absolute.
    [[ ! ${hosted_zone_name} =~ \.$ ]] \
        && hosted_zone_name="${hosted_zone_name}."

    local hosted_zone_id=$(aws route53 list-hosted-zones-by-name \
        --region ${AWS_REGION} \
        --query "HostedZones[?Name=='${hosted_zone_name}'].Id" \
        --output text)

    [[ -z ${hosted_zone_id-} ]] \
        && echoerr "ERROR: No Id found for ${hosted_zone_name}" \
        && return 1 \
        || echo ${hosted_zone_id}
}

route53_internal_hosted_zone_id () {
    # Return a string of the Internal hosted_zone_id created inside a stack
    local stack_name=$1
    stack_value_output ${stack_name} InternalRoute53HostedZoneId
    return $?
}

route53_list_name () {
    local hosted_zone_name=$1

    local hosted_zone_id=$(aws route53 list-hosted-zones \
        --region ${AWS_REGION} \
        --query "HostedZones[?Name=='${hosted_zone_name}'].Id" \
        --output text)
    [[ -z ${hosted_zone_id-} ]] \
        && echoerr "ERROR: Unable to find 'Id' for zone '${hosted_zone_name}'" \
        && return 1

    local record_type
    for record_type in A CNAME; do
        aws route53 list-resource-record-sets \
            --region ${AWS_REGION} \
            --hosted-zone-id ${hosted_zone_id} \
            --query "ResourceRecordSets[?Type=='${record_type}'].{Name:Name,${record_type}:ResourceRecords[].Value}" \
            --output text
    done
}

route53_list_external () { return;}

route53_list_host_records () {
    local stack_name=$1
    local hosted_zone_id=$2
    aws route53 list-resource-record-sets \
        --region ${AWS_REGION} \
        --hosted-zone-id ${hosted_zone_id} \
        --query "ResourceRecordSets[?ResourceRecords[?contains(Value, '${stack_name}')]].Name" \
        --output text
}

route53_list_hosted_zones () {
    echoerr "INFO: Listing available hosted zones"
    aws route53 list-hosted-zones \
        --region ${AWS_REGION} \
        --query "HostedZones[].Name" \
        --output text
    return $?
}

route53_list_internal () {
    local stack_name=$1

    local record
    local record_type
    local -a records

    local hosted_zone_id=$(route53_internal_hosted_zone_id ${stack_name})
    [[ -z ${hosted_zone_id-} ]] && return 1

    for record_type in A CNAME; do
        echoerr "INFO: Listing ${record_type} records"
        records=($(route53_list_type_records ${hosted_zone_id} ${record_type}))
        if [[ ${records[@]-} ]]; then
            for record in ${records[@]}; do
                echoerr "  ${record}"
            done
        else
            echoerr "INFO: No ${record_type} records found"
        fi
    done
}

route53_list_type_records () {
    # Enumerate all ${type} records for a ${hosted_zone_id} and return an array
    # of FQDNs. Currently we only support enumerating either A or CNAME records.
    local hosted_zone_id=$1
    [[ ! ${2} =~ ^(A|CNAME)$ ]] \
        && echoerr "ERROR: Unsupported type '${2}'" \
        && return 1 \
        || local type=$2

    aws route53 list-resource-record-sets \
        --region ${AWS_REGION} \
        --hosted-zone-id ${hosted_zone_id} \
        --query "ResourceRecordSets[?Type=='${type}'].Name" \
        --output text
    return $?
}

route53_vpc_associate () {
    # Associate a ${vpc} with the ${hosted_zone_id}. This permits ${vpc} to query
    # all records in the ${hosted_zone_id}
    local hosted_zone_id=$1
    local vpc=$2

    local hosted_zone_name=$(route53_zone_name_from_id ${hosted_zone_id})
    [[ -z ${hosted_zone_name-} ]] && return 1

    echoerr "INFO: Associating ${vpc} to ${hosted_zone_id} (${hosted_zone_name})"
    local change_id=$(aws route53 associate-vpc-with-hosted-zone \
        --region ${AWS_REGION} \
        --hosted-zone-id ${hosted_zone_id} \
        --vpc "VPCRegion=${AWS_REGION},VPCId=${vpc}" \
        --query "ChangeInfo.Id" \
        --output text)

    [[ -z ${change_id-} ]] \
        && echoerr "ERROR: Failed to submit change" \
        && return 1

    echoerr "INFO: Waiting for ${change_id} to complete..."
    aws route53 wait resource-record-sets-changed --id ${change_id}
}

route53_vpc_dissociate () {
    # Remove the association of ${vpc} with ${hosted_zone_id}. This revokes the
    # ability for ${vpc} to query all records in the ${hosted_zone_id}
    local hosted_zone_id=$1
    local vpc=$2

    local hosted_zone_name=$(route53_zone_name_from_id ${hosted_zone_id})
    [[ -z ${hosted_zone_name-} ]] && return 1

    echoerr "INFO: Dissociating ${vpc} from ${hosted_zone_id} (${hosted_zone_name})"
    local change_id=$(aws route53 disassociate-vpc-from-hosted-zone \
        --region ${AWS_REGION} \
        --hosted-zone-id ${hosted_zone_id} \
        --vpc "VPCRegion=${AWS_REGION},VPCId=${vpc}" \
        --query "ChangeInfo.Id" \
        --output text)

    [[ -z ${change_id-} ]] \
        && echoerr "ERROR: Failed to submit change" \
        && return 1

    echoerr "INFO: Waiting for ${change_id} to complete..."
    aws route53 wait resource-record-sets-changed --id ${change_id}
}

route53_zone_name_from_id () {
    local hosted_zone_id=$1

    local hosted_zone_name=$(aws route53 list-hosted-zones \
        --region ${AWS_REGION} \
        --query "HostedZones[?Id=='/hostedzone/${hosted_zone_id}'].Name" \
        --output text)
    [[ -z ${hosted_zone_name-} ]] \
        && echoerr "ERROR: No Name found for ${hosted_zone_id}" \
        && return 1 \
        || echo ${hosted_zone_name}
}


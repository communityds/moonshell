#!/usr/bin/env bash
#
# VPC FUNCTIONS
#
vpc_id_from_stack_name () {
    # Find the VPCId for ${stack_name}
    local stack_name=$1

    stack_resource_type_id ${stack_name} "AWS::EC2::VPC"
    return $?
}

vpc_internal_hosted_zone_id () {
    # Return the string of the Internal hosted_zone_id inside ${vpc}
    local vpc_id=$1

    local stack_name=$(stack_name_from_vpc_id ${vpc_id})
    stack_value_output ${stack_name} InternalRoute53HostedZoneId
    return $?
}

vpc_peer_associate () {
    # Create and accept a peering connection between two VPCs. The active
    # AWS account must have permission to accept the peering request on the
    # target VPC
    local source_vpc_id=$1
    local target_vpc_id=$2

    echoerr "INFO: Creating peering connection between ${source_vpc_id} and ${target_vpc_id}"
    local peering_id=$(aws ec2 create-vpc-peering-connection \
        --region ${AWS_REGION} \
        --vpc-id ${source_vpc_id} \
        --peer-vpc-id ${target_vpc_id} \
        --query "VpcPeeringConnection.VpcPeeringConnectionId" \
        --output text)
    [[ -z ${peering_id-} ]] \
        && echoerr "ERROR: failed to create a peering connection" \
        && return 1

    echoerr "INFO: Accepting Peering Connection"
    aws ec2 accept-vpc-peering-connection \
        --region ${AWS_REGION} \
        --vpc-peering-connection-id ${peering_id} \
        >/dev/null
    local retr=$?

    if [[ ${retr} == 0 ]]; then
        echo ${peering_id}
        return 0
    else
        echoerr "ERROR: Peering Connection Association failed"
        return ${retr}
    fi
}

vpc_peer_connection () {
    # Returns the name of the ${peering_connection}, if one exists. A VPC should
    # never be associated with the same VPC multiple times, and tooling will die
    # if it is.
    local req_vpc_id=$1
    local acc_vpc_id=$2

    echoerr "INFO: Searching for peering connections from ${req_vpc_id}"
    local peering_connections=($(aws ec2 describe-vpc-peering-connections \
        --region ${AWS_REGION} \
        --filters \
            Name=requester-vpc-info.vpc-id,Values=${req_vpc_id} \
            Name=accepter-vpc-info.vpc-id,Values=${acc_vpc_id} \
            Name=status-code,Values=active,pending-acceptance,provisioning \
        --query "VpcPeeringConnections[].VpcPeeringConnectionId" \
        --output text))

    if [[ ${peering_connections[@]-} ]]; then
        if [[ ${#peering_connections[@]} == 1 ]]; then
            echoerr "INFO: Existing peering connection found"
            echo ${peering_connections}
            return 0
        else
            echoerr "INFO: Multiple peering connections found."
            echo ${peering_connections[@]}
            return 0
        fi
    else
        echoerr "INFO: No peering connections found"
        return 0
    fi
}

vpc_peer_dissociate () {
    # Delete an existing peering connection between two VPCs.
    local source_vpc_id=$1
    local target_vpc_id=$2
}

vpc_peers_from_requester () {
    local req_vpc_id=$1

    aws ec2 describe-vpc-peering-connections \
        --region ${AWS_REGION} \
        --filters \
            Name=requester-vpc-info.vpc-id,Values=${req_vpc_id} \
            Name=status-code,Values=active,pending-acceptance,provisioning \
        --query "VpcPeeringConnections[].VpcPeeringConnectionId" \
        --output text
    return $?
}

vpc_peers_to_accepter () {
    local acc_vpc_id=$1

    aws ec2 describe-vpc-peering-connections \
        --region ${AWS_REGION} \
        --filters \
            Name=accepter-vpc-info.vpc-id,Values=${acc_vpc_id} \
            Name=status-code,Values=active,pending-acceptance,provisioning \
        --query "VpcPeeringConnections[].VpcPeeringConnectionId" \
        --output text
    return $?
}


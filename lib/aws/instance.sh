#!/usr/bin/env bash
#
# INSTANCE FUNCTIONS
#
instance_public_ip () {
    local instance_id=$1

    aws ec2 describe-instances \
        --region ${AWS_REGION} \
        --instance-ids ${instance_id} \
        --query "Reservations[*].Instances[*].{IP:PublicIpAddress,ID:InstanceId}" \
        --output text
    return $?
}

instance_private_ip () {
    local instance_id=$1

    aws ec2 describe-instances \
        --region ${AWS_REGION} \
        --instance-ids ${instance_id} \
        --query "Reservations[*].Instances[*].{IP:PrivateIpAddress,ID:InstanceId}" \
        --output text
    return $?
}

instances_running_ami () {
    # Return a list of running instances using ${ami_id}
    local ami_id=$1
    aws ec2 describe-instances \
        --region ${AWS_REGION} \
        --filter Name=image-id,Values=${ami_id} \
        --query "Reservations[].Instances[].InstanceId" \
        --output text
    return $?
}

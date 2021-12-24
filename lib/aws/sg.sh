#!/usr/bin/env bash
#
#
#

sg_group_list () {
    local stack_name="$1"

    stack_resource_type_name ${stack_name} "AWS::EC2::SecurityGroup"
}

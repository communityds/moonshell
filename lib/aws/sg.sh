#!/usr/bin/env bash
#
#
#

sg_group_list () {
    if [[ $# -lt 1 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    stack_resource_type_name ${stack_name} "AWS::EC2::SecurityGroup"
}

#!/usr/bin/env bash
#
#
#
[[ -z ${AWS_REGION-} ]] \
    && export AWS_REGION="ap-southeast-2" \
    || true

[[ -z ${AWS_DEFAULT_REGION-} ]] \
    && export AWS_DEFAULT_REGION=${AWS_REGION} \
    || true

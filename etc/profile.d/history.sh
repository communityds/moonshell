#!/usr/bin/env bash
#
# This makes the output recorded to ~/.bash_history contain a timestamp and be,
# for intents and purposes, infinite.
#
export HISTTIMEFORMAT='%Y%m%d%H%M%S - '
export HISTSIZE=1000000000

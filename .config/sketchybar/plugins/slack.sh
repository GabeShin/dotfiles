#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

_SSDF_SB_SLACK_STATUS_LABEL=$(lsappinfo info -only StatusLabel Slack | sed -n 's/.*"label"="\(.*\)".*/\1/p')

sketchybar --set "$NAME" label="${_SSDF_SB_SLACK_STATUS_LABEL}" label.color="${RED}"

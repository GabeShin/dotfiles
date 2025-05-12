#!/usr/bin/env bash

sketchybar --add item slack right
sketchybar --set slack \
   icon=":slack:" \
   icon.font='sketchybar-app-font:Regular:16.0'
   update_freq=60 \
   script="${CONFIG_DIR}/plugins/slack.sh"


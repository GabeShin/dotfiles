#!/usr/bin/env bash

sketchybar --add item slack right
sketchybar --set slack \
   icon.font='sketchybar-app-font:Regular:16.0' \
   update_freq=60 \
   script="${PLUGIN_DIR}/slack.sh" \
   background.padding_left=15 \
   icon.font.size=20 \
   --subscribe slack system_woke

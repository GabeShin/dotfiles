#!/usr/bin/env bash

# updates=on is required: the global default is updates=when_shown, and this
# item starts with drawing=off, so a when_shown item would never run its script
# and could never turn itself on.
sketchybar --add event agent_notified

sketchybar --add item agent_notify right \
           --set agent_notify drawing=off \
                              updates=on \
                              update_freq=5 \
                              icon.font="MesloLGL Nerd Font:Bold:15.0" \
                              icon.padding_right=6 \
                              label.max_chars=45 \
                              background.padding_left=8 \
                              click_script="sketchybar --set agent_notify drawing=off" \
                              script="$PLUGIN_DIR/agent_notify.sh" \
           --subscribe agent_notify agent_notified mouse.clicked

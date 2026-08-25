#!/bin/bash

# Quota readout for every Claude / Codex subscription, drawn as a sparkline --
# one fixed cell per account, height by weekly usage. State comes from
# ~/.config/agent-usage/agent-usage.sh; see plugins/agent_usage.sh for the
# rendering and the popup rows for the full breakdown on click.

# updates=on is required: the global default is updates=when_shown, and this
# item starts with drawing=off, so a when_shown item would never run its
# script and could never turn itself on. Same reason as agent_notify.
sketchybar --add event agent_usage_changed

sketchybar --add item agent_usage right \
           --set agent_usage drawing=off \
                             updates=on \
                             update_freq=30 \
                             icon.font="MesloLGL Nerd Font:Bold:14.0" \
                             icon.padding_right=6 \
                             label.font="MesloLGL Nerd Font:Semibold:13.0" \
                             label.max_chars=36 \
                             background.padding_left=8 \
                             popup.align=right \
                             popup.height=26 \
                             script="$PLUGIN_DIR/agent_usage.sh" \
           --subscribe agent_usage agent_usage_changed mouse.clicked

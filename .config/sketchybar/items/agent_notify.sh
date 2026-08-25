#!/usr/bin/env bash

# Agents that want your attention, drawn in the centre of the bar as one chip
# per agent. The chips themselves are created by plugins/agent_notify.sh, which
# is the only thing that knows how many agents there are; this item is the
# anchor that owns the script and the refresh timer.
#
# Centre, not right: a blocked agent is an interrupt, and the middle of the
# screen is where the eye already is. The centre is otherwise empty, so the
# cluster costs nothing when no agent is waiting.
#
# updates=on is required: the global default is updates=when_shown, and this
# item starts with drawing=off, so a when_shown item would never run its script
# and could never turn itself on.
sketchybar --add event agent_notified

sketchybar --add item agent_notify center \
           --set agent_notify drawing=off \
                              updates=on \
                              update_freq=5 \
                              icon.drawing=off \
                              label.drawing=off \
                              width=0 \
                              script="$PLUGIN_DIR/agent_notify.sh" \
           --subscribe agent_notify agent_notified mouse.clicked

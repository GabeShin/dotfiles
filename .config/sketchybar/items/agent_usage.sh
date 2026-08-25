#!/usr/bin/env bash

# Quota readout for every Claude / Codex subscription: the icon, a row of
# segments (one per account), and a trailing hint naming where to work next.
#
# Why a row of items and not one label: a label is a single string with a
# single colour, so the previous sparkline had to pick one colour for all six
# accounts. It chose the worst account's, which painted five healthy accounts
# in the colour of the one that was spent -- and the distribution was the whole
# reason to draw six cells.
#
# The segments are allocated here, empty, rather than created on demand by the
# plugin. Right-hand items are laid out from the right edge inward in the order
# they are added, but only while the config is being parsed; items added later,
# at runtime, land at the far right of the bar instead. Allocating the slots up
# front is what keeps the cluster next to its icon and off the clock's toes.
# Unused slots draw nothing and cost nothing, so the pool is simply generous.
SEG_SLOTS=12

sketchybar --add event agent_usage_changed

seg=(--add item agent_usage.seg.hint right
     --set agent_usage.seg.hint
           icon.drawing=off
           label.font="$FONT:Semibold:13.0"
           label.padding_left=7
           label.padding_right=8
           click_script="$PLUGIN_DIR/agent_usage.sh popup")

# Each slot carries a faint track behind its bar. Eighth-block characters grow
# from the baseline, so without one a quiet account is a two-pixel dash floating
# in space -- indistinguishable from a rendering artefact, and impossible to
# read a height against. The track is switched off for the divider slot, which
# is a separator rather than a reading.
#
# Reverse order: the first added sits furthest right, so slot 0 must go last.
for (( i = SEG_SLOTS - 1; i >= 0; i-- )); do
    seg+=(--add item "agent_usage.seg.s$i" right
          --set "agent_usage.seg.s$i"
                drawing=off
                icon.drawing=off
                label.font="MesloLGL Nerd Font:Bold:15.0"
                label.padding_left=2
                label.padding_right=2
                label.shadow.drawing=off
                background.color=0x22ffffff
                background.corner_radius=2
                background.height=22
                background.border_width=0
                click_script="$PLUGIN_DIR/agent_usage.sh popup")
done
sketchybar "${seg[@]}"

# Added last, so it sits furthest left: the icon heads the row it labels.
#
# updates=on is required: the global default is updates=when_shown, and this
# item starts with drawing=off, so a when_shown item would never run its script
# and could never turn itself on. Same reason as agent_notify.
sketchybar --add item agent_usage right \
           --set agent_usage drawing=off \
                             updates=on \
                             update_freq=30 \
                             icon="$AGENT_USAGE" \
                             icon.font="MesloLGL Nerd Font:Bold:15.0" \
                             icon.padding_left=8 \
                             icon.padding_right=7 \
                             label.drawing=off \
                             popup.align=right \
                             popup.height=26 \
                             script="$PLUGIN_DIR/agent_usage.sh" \
           --subscribe agent_usage agent_usage_changed mouse.clicked

# One background around the lot, so nine items still read as one component.
members=(agent_usage)
for (( i = 0; i < SEG_SLOTS; i++ )); do members+=("agent_usage.seg.s$i"); done
members+=(agent_usage.seg.hint)
sketchybar --add bracket agent_usage.group "${members[@]}" \
           --set agent_usage.group background.drawing=on \
                                   background.color="$BACKGROUND_1" \
                                   background.corner_radius=9 \
                                   background.height=26 \
                                   background.border_width=0

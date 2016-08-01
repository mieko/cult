#!/bin/sh

export TERM='screen-256color'
export CULT_PROJECT="$1"
exec tmux -2 -f "$(dirname "$0")/tmux.conf" attach-session -t 'cult'

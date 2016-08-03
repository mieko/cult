#!/bin/sh

export TERM='screen-256color'
export CULT_PROJECT="$1"

tmux -V &>/dev/null || "$(dirname "$0")/install_tmux.sh" || exit 1

exec tmux -2 -f "$(dirname "$0")/tmux.conf" attach-session -t 'cult'

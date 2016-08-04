#!/bin/sh
export CULT_PROJECT="$1"

tmux -V &>/dev/null || "$(dirname "$0")/install_tmux.sh" || exit 1

exec tmux -f "$(dirname "$0")/tmux.conf" attach-session -t 'cult'

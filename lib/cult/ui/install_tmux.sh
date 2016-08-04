#!/bin/sh

tmux -V &> /dev/null && exit 0

echo "Cult's UI requires tmux to be installed, but it didn't execute in" \
     "your path."

if [ `uname` == 'Linux' -a -f /etc/debian_version ]; then
  COMMAND="sudo apt-get install tmux"
elif [ `uname` == 'Linux' -a -f /etc/fedora-release ]; then
  which dnf &> /dev/null && \
       COMMAND="sudo dnf install tmux" \
    || COMMAND="sudo yum install tmux"
elif [ `uname` == 'Darwin' ]; then
  if brew -v &> /dev/null ; then
    COMMAND="brew update; brew install tmux"
  elif port version &> /dev/null ; then
    COMMAND="port install tmux"
  else
    ERRMSG="macOS was detected, but neither 'brew' nor 'port' is available"
  fi
elif freebsd-version &> /dev/null ; then
  COMMAND="sudo pkg install tmux"
fi

if [ -z "$COMMAND" ]; then
  if [ -z "$ERRMSG" ]; then
    echo "No suggestion for installation command on this system."
  else
    echo "$ERRMSG"
  fi
  exit 1
fi

echo "tmux can be installed with the following command:"
echo
echo "  $COMMAND"
echo
echo "Press Enter to do so, or ctrl-c to abort."
read

exec $COMMAND

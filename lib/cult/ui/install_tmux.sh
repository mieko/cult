#!/bin/sh

if tmux -V &>/dev/null ; then
  exit 0
fi

echo "Cult's UI requires tmux to be installed, but it didn't find it in " \
     "your path.  We can totally install it for you, though:"

if [ -f /etc/debian_version ]; then
  COMMAND="sudo apt-get install tmux"
elif [ `uname` == 'Darwin' ]
  COMMAND="sudo brew install tmux"
elif [ -f /etc/fedora-release ]; then
  which dnf &> /dev/null && \
       COMMAND="sudo dnf install tmux" \
    || COMMAND="sudo yum install tmux"
elif freebsd-version &> /dev/null
  COMMAND="sudo pkg install tmux"
fi

if [-z "$COMMAND" ]; then
  echo "I lied.  I tried a bunch of common setups, but yours wasn't one of " \
       "them.  Perhaps try installing tmux yourself and give it another shot?"
  echo
  echo "And let us know how we could've installed tmux at the cult GitHub page."
  exit 1
fi

echo "The crystal ball says I can install tmux by running the following command:"
echo
echo "  $COMMAND"
echo
echo "Press ENTER to do so, or ctrl-c to abort."
read

"$COMMAND"

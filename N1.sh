#!/bin/bash

# This file is sym-linked to the `electron` executable.
# It is used by `apm` when calling commands.

if [ "$(uname)" == 'Darwin' ]; then
  OS='Mac'
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  OS='Linux'
elif [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  OS='Cygwin'
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

while getopts ":wtfvh-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        wait)
          WAIT=1
          ;;
        help|version)
          REDIRECT_STDERR=1
          EXPECT_OUTPUT=1
          ;;
        foreground|test)
          EXPECT_OUTPUT=1
          ;;
      esac
      ;;
    w)
      WAIT=1
      ;;
    h|v)
      REDIRECT_STDERR=1
      EXPECT_OUTPUT=1
      ;;
    f|t)
      EXPECT_OUTPUT=1
      ;;
  esac
done

if [ $REDIRECT_STDERR ]; then
  exec 2> /dev/null
fi

N1_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
export N1_PATH

if [ $OS == 'Mac' ]; then
  if [ -z "$N1_PATH" ]; then
    echo "Set the N1_PATH environment variable to the absolute location of the main edgehill folder."
    exit 1
  fi

  ELECTRON_PATH=${ELECTRON_PATH:-$N1_PATH/electron} # Set ELECTRON_PATH unless it is already set

  # Exit if Atom can't be found
  if [ ! -d "$ELECTRON_PATH" ]; then
    echo "Cannot locate electron. Be sure you have run script/bootstrap first from $N1_PATH"
    exit 1
  fi

  # We find the electron executable inside of the electron directory.
  $ELECTRON_PATH/Electron.app/Contents/MacOS/Electron --executed-from="$(pwd)" --pid=$$ "$@" $N1_PATH

elif [ $OS == 'Linux' ]; then
  DOT_INBOX_DIR="$HOME/.nylas"

  mkdir -p "$DOT_INBOX_DIR"

  if [ -z "$N1_PATH" ]; then
    echo "Set the N1_PATH environment variable to the absolute location of the main N1 folder."
    exit 1
  fi

  ELECTRON_PATH=${ELECTRON_PATH:-$N1_PATH/electron} # Set ELECTRON_PATH unless it is already set

  # Exit if Atom can't be found
  if [ ! -d "$ELECTRON_PATH" ]; then
    echo "Cannot locate electron. Be sure you have run script/bootstrap first from $N1_PATH"
    exit 1
  fi

  # We find the electron executable inside of the electron directory.
  $ELECTRON_PATH/electron --executed-from="$(pwd)" --pid=$$ "$@" $N1_PATH

fi

# Exits this process when Atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# If the wait flag is set, don't exit this process until Atom tells it to.
if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi

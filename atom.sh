#!/bin/bash

# This file is sym-linked to the `atom` executable.
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

if [ $OS == 'Mac' ]; then
  if [ -z "$EDGEHILL_PATH" ]; then
    echo "Set the EDGEHILL_PATH environment variable to the absolute location of the main edgehill folder."
    exit 1
  fi

  ATOM_SHELL_PATH=${ATOM_SHELL_PATH:-$EDGEHILL_PATH/atom-shell} # Set ATOM_SHELL_PATH unless it is already set

  # Exit if Atom can't be found
  if [ -z "$ATOM_SHELL_PATH" ]; then
    echo "Cannot locate atom-shell. Be sure you have run script/grunt download-atom-shell first from $EDGEHILL_PATH"
    exit 1
  fi

  # We find the atom-shell executable inside of the atom-shell directory.
  $ATOM_SHELL_PATH/Atom.app/Contents/MacOS/Atom --executed-from="$(pwd)" --pid=$$ "$@" $EDGEHILL_PATH

elif [ $OS == 'Linux' ]; then
  DOT_INBOX_DIR="$HOME/.nylas"

  mkdir -p "$DOT_INBOX_DIR"

  if [ -z "$EDGEHILL_PATH" ]; then
    echo "Set the EDGEHILL_PATH environment variable to the absolute location of the main edgehill folder."
    exit 1
  fi

  ATOM_SHELL_PATH=${ATOM_SHELL_PATH:-$EDGEHILL_PATH/atom-shell} # Set ATOM_SHELL_PATH unless it is already set

  # Exit if Atom can't be found
  if [ -z "$ATOM_SHELL_PATH" ]; then
    echo "Cannot locate atom-shell. Be sure you have run script/grunt download-atom-shell first from $EDGEHILL_PATH"
    exit 1
  fi

  # We find the atom-shell executable inside of the atom-shell directory.
  $ATOM_SHELL_PATH/atom --executed-from="$(pwd)" --pid=$$ "$@" $EDGEHILL_PATH

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

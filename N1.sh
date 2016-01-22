#!/bin/bash

N1_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );

if [ "$(uname)" == 'Darwin' ]; then
  OS='Mac'
  ELECTRON_PATH=${ELECTRON_PATH:-$N1_PATH/electron/Electron.app/Contents/MacOS/Electron}
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  OS='Linux'
  ELECTRON_PATH=${ELECTRON_PATH:-$N1_PATH/electron/electron}
  mkdir -p "$HOME/.nylas"
elif [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  OS='Cygwin'
  ELECTRON_PATH=${ELECTRON_PATH:-$N1_PATH/electron/electron.exe}
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

if [ ! -e "$ELECTRON_PATH" ]; then
  echo "Can't find the Electron executable at $ELECTRON_PATH. Be sure you have run script/bootstrap first from $N1_PATH or set the ELECTRON_PATH environment variable."
  exit 1
fi

$ELECTRON_PATH --executed-from="$(pwd)" --pid=$$ $N1_PATH "$@"
exit $?

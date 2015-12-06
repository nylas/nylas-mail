#!/bin/bash

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

if [ "$(basename $0)" == 'nylas-beta' ]; then
  BETA_VERSION=true
else
  BETA_VERSION=
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

if [ $EXPECT_OUTPUT ]; then
  export ELECTRON_ENABLE_LOGGING=1
fi

if [ $OS == 'Mac' ]; then
  if [ -n "$BETA_VERSION" ]; then
    NYLAS_APP_NAME="Nylas N1 Beta.app"
  else
    NYLAS_APP_NAME="Nylas N1.app"
  fi

  if [ -z "${NYLAS_PATH}" ]; then
    # If NYLAS_PATH isnt set, check /Applications and then ~/Applications for Nylas N1.app
    if [ -x "/Applications/$NYLAS_APP_NAME" ]; then
      NYLAS_PATH="/Applications"
    elif [ -x "$HOME/Applications/$NYLAS_APP_NAME" ]; then
      NYLAS_PATH="$HOME/Applications"
    else
      # We havent found an Nylas N1.app, use spotlight to search for N1
      NYLAS_PATH="$(mdfind "kMDItemCFBundleIdentifier == 'com.nylas.nylas-mail'" | grep -v ShipIt | head -1 | xargs -0 dirname)"

      # Exit if N1 can't be found
      if [ ! -x "$NYLAS_PATH/$NYLAS_APP_NAME" ]; then
        echo "Cannot locate 'Nylas N1.app', it is usually located in /Applications. Set the NYLAS_PATH environment variable to the directory containing 'Nylas N1.app'."
        exit 1
      fi
    fi
  fi

  if [ $EXPECT_OUTPUT ]; then
    "$NYLAS_PATH/$NYLAS_APP_NAME/Contents/MacOS/Nylas" --executed-from="$(pwd)" --pid=$$ "$@"
    exit $?
  else
    open -a "$NYLAS_PATH/$NYLAS_APP_NAME" -n --args --executed-from="$(pwd)" --pid=$$ --path-environment="$PATH" "$@"
  fi
elif [ $OS == 'Linux' ]; then
  SCRIPT=$(readlink -f "$0")
  USR_DIRECTORY=$(readlink -f $(dirname $SCRIPT)/..)

  if [ -n "$BETA_VERSION" ]; then
    NYLAS_PATH="$USR_DIRECTORY/share/nylas-beta/nylas"
  else
    NYLAS_PATH="$USR_DIRECTORY/share/nylas/nylas"
  fi

  NYLAS_HOME="${NYLAS_HOME:-$HOME/.nylas}"
  mkdir -p "$NYLAS_HOME"

  : ${TMPDIR:=/tmp}

  [ -x "$NYLAS_PATH" ] || NYLAS_PATH="$TMPDIR/nylas-build/Nylas/nylas"

  if [ $EXPECT_OUTPUT ]; then
    "$NYLAS_PATH" --executed-from="$(pwd)" --pid=$$ "$@"
    exit $?
  else
    (
    nohup "$NYLAS_PATH" --executed-from="$(pwd)" --pid=$$ "$@" > "$NYLAS_HOME/nohup.out" 2>&1
    if [ $? -ne 0 ]; then
      cat "$NYLAS_HOME/nohup.out"
      exit $?
    fi
    ) &
  fi
fi

# Exits this process when N1 exits
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# If the wait flag is set, don't exit this process until N1 tells it to.
if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi

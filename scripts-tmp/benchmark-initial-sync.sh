#!/bin/bash

set -e

function print_help {
  OUTPUT=$(cat <<- EOM

    A script to benchmark the initial sync performance of Nylas Mail. To use,
    simply run the script after authing whatever accounts you wish to measure
    in your development version of Nylas Mail. The benchmarking script will
    clear all of the data except for your accounts and open and close Nylas
    Mail several times, printing out the number of messages synced after each
    iteration.
  )
  echo "$OUTPUT"
}

if [[ $1 == '-h' || $1 == '--help' ]]
then
  print_help
  exit 0
fi

# Run sudo to prime root privileges
sudo ls > /dev/null

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NYLAS_DIR="$HOME/.nylas-dev"
EDGEHILL_DB="$NYLAS_DIR/edgehill.db"
TIME_LIMIT=120
ITERS=5

for i in `seq 1 $ITERS`
do
  bash $CWD/drop-data-except-accounts.sh > /dev/null

  (npm start &> /dev/null &)

  sleep $TIME_LIMIT

  ELECTRON_PID=`ps aux | grep "Electron packages/client-app" | grep -v grep | awk '{print $2}'`
  sudo kill -9 $ELECTRON_PID

  MESSAGE_COUNT=`sqlite3 $EDGEHILL_DB 'SELECT COUNT(*) FROM Message'`
  echo "Synced Messages: $MESSAGE_COUNT"

  # Sometimes it takes a while to shutdown
  while [[ $ELECTRON_PID != '' ]]
  do
    sleep 1
    ELECTRON_PID=`ps aux | grep "Electron packages/client-app" | grep -v grep | awk '{print $2}'`
  done
done

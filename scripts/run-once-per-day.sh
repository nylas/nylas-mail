#!/bin/bash

# This just checks the time every 60 seconds to see if it should run the benchmarks.
# This is a hack to work around cron's/automator's inability to start GUI apps
# using `npm start`.

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARK_SCRIPT=$CWD/benchmark-new-commits.sh
TARGET_TIME="$1"

if [[ $# != 1 ]]
then
  echo "Usage: run-once-per-day.sh '23:00'"
  exit 1
fi

while [[ true ]]
do
    CURRENT_TIME=$(date +"%H:%M")

    if [[ $CURRENT_TIME = $TARGET_TIME ]]
    then
        /bin/bash $BENCHMARK_SCRIPT
    fi
    sleep 60
done


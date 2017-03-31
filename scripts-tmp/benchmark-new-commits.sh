#!/bin/bash

set -e

function get_next_commit() {
  local LAST_COMMIT=$1
  local NEXT_COMMIT=$(git log master ^$LAST_COMMIT --ancestry-path --pretty=oneline | cut -d" " -f1 | tail -n 1)
  echo "$NEXT_COMMIT"
}

BENCHMARK_RESULTS_DIR="$HOME/.benchmark_results"
mkdir -p $BENCHMARK_RESULTS_DIR

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LAST_COMMIT=$(cat $BENCHMARK_RESULTS_DIR/last_commit)
NEXT_COMMIT=$(get_next_commit $LAST_COMMIT)

git checkout -q master
git pull -q --rebase

while [[ $NEXT_COMMIT != '' ]]
do
  echo $NEXT_COMMIT
  git checkout -q $NEXT_COMMIT
  bash $CWD/benchmark-initial-sync.sh > "$BENCHMARK_RESULTS_DIR/$NEXT_COMMIT-results.txt"
  echo "$NEXT_COMMIT" > "$BENCHMARK_RESULTS_DIR/last_commit"
  NEXT_COMMIT=$(get_next_commit $NEXT_COMMIT)
done

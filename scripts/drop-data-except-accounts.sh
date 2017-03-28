#!/bin/bash

set -e

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NYLAS_DIR="$HOME/.nylas-dev"
TRUNCATE_TABLES="
Account 
AccountPluginMetadata 
Calendar 
Category 
Contact 
ContactSearch 
Event 
EventSearch 
File 
Message 
MessageBody 
MessagePluginMetadata 
ProviderSyncbackRequest
Thread 
ThreadCategory 
ThreadContact 
ThreadCounts 
ThreadPluginMetadata 
ThreadSearch"
SQLITE_DIR=$CWD/sqlite
SQLITE_BIN=$SQLITE_DIR/sqlite3
SQLITE_SRC_DIR="$SQLITE_DIR/sqlite-amalgamation-3170000"

# Build the sqlite3 amalgamation if necessary because we need FTS5 support.
if [[ ! -e "$SQLITE_BIN" ]]
then
  mkdir -p $SQLITE_DIR
  curl -s "https://www.sqlite.org/2017/sqlite-amalgamation-3170000.zip" > "$SQLITE_DIR/sqlite-amalgamation.zip"
  unzip -o -d $SQLITE_DIR "$SQLITE_DIR/sqlite-amalgamation.zip"
  clang -DSQLITE_ENABLE_FTS5 "$SQLITE_SRC_DIR/sqlite3.c" "$SQLITE_SRC_DIR/shell.c" -o $SQLITE_BIN
fi

rm -f $NYLAS_DIR/a-*.sqlite

EDGEHILL_DB=$NYLAS_DIR/edgehill.db

for TABLE in $TRUNCATE_TABLES
do
  COMMAND="DELETE FROM $TABLE"
  $SQLITE_BIN $EDGEHILL_DB "DELETE FROM $TABLE"
done

$SQLITE_BIN $EDGEHILL_DB 'DELETE FROM JSONBlob WHERE client_id != "NylasID"'

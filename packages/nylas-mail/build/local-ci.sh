#! /usr/bin/env bash
set -e
if [ ! -d "build/resources/certs" ]; then
  echo "Please manually place the unencrypted certs for this operating system into build/resources/certs"
  exit 1
fi

mkdir -p /tmp/nylas
mv build/resources/certs /tmp/nylas/certs
git clean -xdf
mv /tmp/nylas/certs build/resources/certs

export PUBLISH_BUILD=true;
git submodule update --init --recursive
source build/resources/certs/set_unix_env.sh

script/bootstrap
script/grunt ci

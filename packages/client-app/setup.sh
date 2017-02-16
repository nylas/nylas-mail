#!/usr/bin/env bash

# Exit if any command fails
set -e

echo "Setting up Nylas Mail";
rm -f .setup-complete;


echo "---> Ensuring N1 submodule is initialized";
git submodule init;
git submodule update;


echo "---> Copying arcnaist files to N1";
cp -f arc-N1/.arc* N1/;
cp -rf arc-N1/arclib N1/;


echo "---> Copying private packages to N1"
mkdir -p N1/private_packages
cp -rf packages/* N1/private_packages


echo "---> Setting required environment variables"
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

[ -z "$EDGEHILL_PATH" ] && EDGEHILL_PATH="$SCRIPT_DIR/N1"

if env | grep -q ^EDGEHILL_PATH=
then
  echo "---> Already have EDGEHILL_PATH set to '$EDGEHILL_PATH'"
else
  echo "---> Setting EDGEHILL_PATH to '$EDGEHILL_PATH'"
  export EDGEHILL_PATH
fi


echo "---> Checking for correct node version"
command -v node >/dev/null 2>&1 || { echo >&2 "ERROR: Please install node"; exit 1; }

node_version="$(node --version)"
if [ ${node_version:0:5} != "v0.10" ]; then
  if [ "$(uname)" == "Darwin" ]; then
    echo "---> Warning, you don't have the correct version of node installed. You have '$(node --version)'"
    command -v node >/dev/null 2>&1 || { echo >&2 "ERROR: We can't automatically install nvm for you. Setup homebrew, then 'brew install nvm' and use nvm to setup the correct node version."; exit 1; }
    echo "---> We see you have homebrew installed. We're using brew to install nvm to install the correct version of node."
    brew install nvm
    nmv install 0.10
    nvm use 0.10
  else
    echo "ERROR: Nylas Mail requires Node version 0.10.x. You are running '$(node --version)'. Please ensure node 0.10 is node in your path and try again";
    exit 1;
  fi
fi


echo "---> Setting up N1"
cd N1
script/bootstrap


echo "---> DONE!. Run './nylas-mail --dev' to launch in dev mode"
touch .setup-complete

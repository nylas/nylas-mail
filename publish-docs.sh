#!/bin/bash

set -e

# Builds docs and moves the output to gh-pages branch (overwrites)
mkdir -p _docs_output
script/grunt docs
./node_modules/.bin/gitbook --gitbook=latest build . ./_docs_output --log=debug --debug
rm -r docs_src/classes
git checkout gh-pages --quiet
cp -rf _docs_output/* .
rm -r _docs_output

git add .
git status -s
printf "\nNow commit the doc updates! \n\n"

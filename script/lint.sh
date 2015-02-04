#!/bin/bash
# This is invoked by 'arc lint', see .arcconfig.
GO=0
if [ ${1##*.} == "coffee" ]; then GO=1; fi
if [ ${1##*.} == "cjsx" ]; then GO=1; fi
if [ $GO != "1" ]; then exit 0; fi
script/grunt coffeelint:target --target "$*" || true

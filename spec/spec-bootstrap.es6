// Swap out Node's native Promise for Bluebird, which allows us to
// do fancy things like handle exceptions inside promise blocks
global.Promise = require('bluebird');
Promise.longStackTraces();

import jasmineExports from './jasmine';
import NylasEnvConstructor from '../src/nylas-env';

Object.assign(window, {
  NylasEnv: NylasEnvConstructor.loadOrCreate(),
  jasmine: jasmineExports.jasmine,
  it: jasmineExports.it,
  xit: jasmineExports.xit,
  runs: jasmineExports.runs,
  waits: jasmineExports.waits,
  spyOn: jasmineExports.spyOn,
  expect: jasmineExports.expect,
  waitsFor: jasmineExports.waitsFor,
  describe: jasmineExports.describe,
  xdescribe: jasmineExports.xdescribe,
  afterEach: jasmineExports.afterEach,
  beforeEach: jasmineExports.beforeEach,
})

import {runSpecSuite} from './jasmine-helper';
NylasEnv.initialize();
runSpecSuite('./spec-suite');


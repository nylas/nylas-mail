// Swap out Node's native Promise for Bluebird, which allows us to
// do fancy things like handle exceptions inside promise blocks
global.Promise = require('bluebird');
Promise.longStackTraces();

import NylasEnvConstructor from '../src/nylas-env';
window.NylasEnv = NylasEnvConstructor.loadOrCreate();
NylasEnv.initialize();
const loadSettings = NylasEnv.getLoadSettings()

import N1SpecRunner from './n1-spec-runner'
N1SpecRunner.runSpecs(loadSettings);

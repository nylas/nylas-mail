/* eslint import/first: 0 */

// Swap out Node's native Promise for Bluebird, which allows us to
// do fancy things like handle exceptions inside promise blocks
global.Promise = require('bluebird');
Promise.longStackTraces();

import NylasEnvConstructor from '../../src/nylas-env';
window.NylasEnv = NylasEnvConstructor.loadOrCreate();

NylasEnv.initialize();
const loadSettings = NylasEnv.getLoadSettings();

// This must be `required` instead of imported because
// NylasEnv.initialize() must complete before `nylas-exports` and other
// globals are available for import via es6 modules.
require('./n1-spec-runner').default.runSpecs(loadSettings)

/* eslint import/first: 0 */

// Swap out Node's native Promise for Bluebird, which allows us to
// do fancy things like handle exceptions inside promise blocks
import '../../src/promise-extensions';

import AppEnvConstructor from '../../src/app-env';
window.AppEnv = AppEnvConstructor.loadOrCreate();

AppEnv.initialize();
const loadSettings = AppEnv.getLoadSettings();

// This must be `required` instead of imported because
// AppEnv.initialize() must complete before `mailspring-exports` and other
// globals are available for import via es6 modules.
require('./spec-runner').default.runSpecs(loadSettings);

/* eslint import/first: 0 */

// Swap out Node's native Promise for Bluebird, which allows us to
// do fancy things like handle exceptions inside promise blocks
global.Promise = require('bluebird');
Promise.setScheduler(global.setImmediate);

// Like sands through the hourglass, so are the days of our lives.
import './window';

import NylasEnvConstructor from './nylas-env';
window.NylasEnv = NylasEnvConstructor.loadOrCreate();
NylasEnv.initialize();
NylasEnv.startRootWindow();


// Workaround for focus getting cleared upon window creation
const windowFocused = () => {
  window.removeEventListener('focus', windowFocused);
  return setTimeout((() => {
    const elt = document.getElementById('sheet-container');
    if (elt) elt.focus();
  }), 0);
}
window.addEventListener('focus', windowFocused);

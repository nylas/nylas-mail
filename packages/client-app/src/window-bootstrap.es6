/* eslint import/first: 0 */

// Extend the standard promise class a bit
import './promise-extensions';

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

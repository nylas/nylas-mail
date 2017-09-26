/* eslint import/first: 0 */

// Extend the standard promise class a bit
import './promise-extensions';

import AppEnvConstructor from './app-env';
window.AppEnv = AppEnvConstructor.loadOrCreate();
AppEnv.initialize();
AppEnv.startRootWindow();

// Workaround for focus getting cleared upon window creation
const windowFocused = () => {
  window.removeEventListener('focus', windowFocused);
  return setTimeout(() => {
    const elt = document.getElementById('sheet-container');
    if (elt) elt.focus();
  }, 0);
};
window.addEventListener('focus', windowFocused);

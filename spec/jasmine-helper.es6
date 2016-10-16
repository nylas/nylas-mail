/* eslint global-require:0 */

import jasmineExports from './jasmine';
import TimeReporter from './time-reporter'
import N1GuiReporter from './n1-gui-reporter';
import ConsoleReporter from './console-reporter'

export function runSpecSuite(specSuite) {
  for (const key of Object.keys(jasmineExports)) {
    window[key] = jasmineExports[key]
  }
  const timeReporter = new TimeReporter();
  const consoleReporter = new ConsoleReporter();

  // This needs to be `required` at runtime because terminal-reporter
  // depends on jasmine-tagged, which depends on jasmine-focused, which on
  // require will attempt to extend the `jasmine` object with methods. The
  // `jasmine` object has to be attached to the global scope before it
  // gets extended. This is done in `_extendGlobalWindow` of
  // `N1SpecRunner`
  const N1TerminalReporter = require('./terminal-reporter').default

  const terminalReporter = new N1TerminalReporter();

  const jasmineEnv = jasmineExports.jasmine.getEnv();

  if (NylasEnv.getLoadSettings().showSpecsInWindow) {
    jasmineEnv.addReporter(N1GuiReporter);
  } else {
    jasmineEnv.addReporter(terminalReporter);
  }
  jasmineEnv.addReporter(timeReporter);
  jasmineEnv.addReporter(consoleReporter);

  const div = document.createElement('div');
  div.id = 'jasmine-content';
  document.body.appendChild(div);

  require(specSuite);

  return jasmineEnv.execute();
}

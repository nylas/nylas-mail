/* eslint global-require:0 */
import TimeReporter from './time-reporter'
import N1GuiReporter from './n1-gui-reporter';
import jasmineExports from './jasmine';
import ConsoleReporter from './console-reporter'

class N1SpecRunner {
  runSpecs() {
    this._extendGlobalWindow();
    this._setupJasmine();
    this._requireSpecs();
    this._executeSpecs();
  }

  /**
   * Put jasmine methods on the global scope so they can be used anywhere
   * without importing jasmine.
   */
  _extendGlobalWindow() {
    Object.assign(window, {
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

    // On load, this will require "jasmine-focused" which looks up the
    // global `jasmine` object and extends onto it:
    // fdescribe, ffdescribe, fffdescribe, fit, ffit, fffit
    require('jasmine-tagged');

    this.jasmineEnv = jasmineExports.jasmine.getEnv();
  }

  _setupJasmine() {
    this._addReporters()
    this._initializeDOM()
  }

  _requireSpecs() {
    require("./spec-suite");
  }

  _executeSpecs() {
    this.jasmineEnv.execute();
  }

  _addReporters() {
    const timeReporter = new TimeReporter();
    const consoleReporter = new ConsoleReporter();

    // This needs to be `required` at runtime because terminal-reporter
    // depends on jasmine-tagged, which depends on jasmine-focused, which
    // on require will attempt to extend the `jasmine` object with
    // methods. The `jasmine` object has to be attached to the global
    // scope before it gets extended. This is done in
    // `_extendGlobalWindow`.
    const N1TerminalReporter = require('./terminal-reporter').default

    const terminalReporter = new N1TerminalReporter();

    if (NylasEnv.getLoadSettings().showSpecsInWindow) {
      this.jasmineEnv.addReporter(N1GuiReporter);
    } else {
      this.jasmineEnv.addReporter(terminalReporter);
    }
    this.jasmineEnv.addReporter(timeReporter);
    this.jasmineEnv.addReporter(consoleReporter);
  }

  _initializeDOM() {
    const div = document.createElement('div');
    div.id = 'jasmine-content';
    document.body.appendChild(div);
  }
}
export default new N1SpecRunner()

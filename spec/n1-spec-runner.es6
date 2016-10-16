/* eslint global-require:0 */

import jasmineExports from './jasmine';
import {runSpecSuite} from './jasmine-helper';

class N1SpecRunner {
  runSpecs() {
    this._extendGlobalWindow();
    runSpecSuite('./spec-suite');
    // this._setupJasmine();
    // this._requireSpecs();
    // this._executeSpces();
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
    //
    // fdescribe
    // ffdescribe
    // fffdescribe
    // fit
    // ffit
    // fffit
    require('jasmine-tagged')
  }

  // _setupJasmine() {
  //
  // }
}
export default new N1SpecRunner()

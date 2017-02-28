import applyPolyfills from './polyfills'

export default class JasmineExtensions {
  extend({beforeEach, afterEach} = {}) {
    applyPolyfills()
    global.it = this._makeItAsync(global.it)
    global.fit = this._makeItAsync(global.fit)
    global.beforeAll = this._makeEachOrAllFnAsync(global.beforeAll)
    global.afterAll = this._makeEachOrAllFnAsync(global.afterAll)
    global.beforeEach = this._makeEachOrAllFnAsync(global.beforeEach)
    global.afterEach = this._makeEachOrAllFnAsync(global.afterEach)
    if (beforeEach) {
      global.beforeEach(beforeEach)
    }
    if (afterEach) {
      global.afterEach(afterEach)
    }
  }

  _runAsync(userFn, done) {
    if (!userFn) {
      done()
      return true
    }
    const resp = userFn.apply(this);
    if (resp && resp.then) {
      return resp.then(done).catch((error) => {
        // Throwing an error doesn't register as stopping the test. Instead, run an
        // expect() that will fail and show us the error. We still need to call done()
        // afterwards, or it will take the full timeout to fail.
        expect(error).toBeUndefined()
        done()
      })
    }
    done()
    return resp
  }

  _makeEachOrAllFnAsync(jasmineEachFn) {
    const self = this;
    return (userFn) => {
      return jasmineEachFn(function asyncEachFn(done) {
        self._runAsync.call(this, userFn, done)
      })
    }
  }

  _makeItAsync(jasmineIt) {
    const self = this;
    return (desc, userFn) => {
      return jasmineIt(desc, function asyncIt(done) {
        self._runAsync.call(this, userFn, done)
      })
    }
  }
}

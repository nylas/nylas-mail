import {DatabaseConnector} from 'cloud-core'
import {getTestDatabase, destroyTestDatabase} from '../helpers'

function masterBeforeEach() {
  spyOn(DatabaseConnector, 'forShared').and.callFake(getTestDatabase)
}

async function masterAfterEach() {
  await destroyTestDatabase();
}

export default class JasmineExtensions {
  extend() {
    global.it = this._makeItAsync(global.it)
    global.fit = this._makeItAsync(global.fit)
    global.beforeEach = this._makeEachFnAsync(global.beforeEach)
    global.afterEach = this._makeEachFnAsync(global.afterEach)
    global.beforeEach(masterBeforeEach)
    global.afterEach(masterAfterEach)
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

  _makeEachFnAsync(jasmineEachFn) {
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

/* eslint no-restricted-syntax: 0 */

require('promise.prototype.finally')
const props = require('promise-props');
const _ = require('underscore')

global.Promise.prototype.thenReturn = function thenReturn(value) {
  return this.then(function then() { return Promise.resolve(value); })
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function each(iterable, iterator) {
  return Promise.resolve(iterable).then((array) => {
    return new Promise((resolve, reject) => {
      Array.from(array).reduce((prevPromise, item, idx, len) => (
        prevPromise.then(() => Promise.resolve(iterator(item, idx, len)))
      ), Promise.resolve())
      .then(() => resolve(iterable))
      .catch((err) => reject(err))
    })
  })
}

function promisify(nodeFn) {
  return function wrapper(...fnArgs) {
    return new Promise((resolve, reject) => {
      nodeFn.call(this, ...fnArgs, (err, ...results) => {
        if (err) {
          reject(err)
          return
        }
        resolve(...results)
      });
    })
  }
}

function promisifyAll(obj) {
  for (const key in obj) {
    if (!key.endsWith('Async') && _.isFunction(obj[key])) {
      obj[`${key}Async`] = promisify(obj[key])
    }
  }
  return obj
}

module.exports = {
  each,
  sleep,
  promisify,
  promisifyAll,
  props: props,
}

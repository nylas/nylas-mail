require('promise.prototype.finally')
const _ = require('underscore')

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function each(iterable, iterator) {
  return Promise.resolve(iterable)
  .then((iter) => Array.from(iter))
  .then((array) => {
    return new Promise((resolve, reject) => {
      array.reduce((prevPromise, item, idx, len) => (
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
  for(const key in obj) {
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
}

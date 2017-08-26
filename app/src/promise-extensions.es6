const MAGIC_KEY = '__isPromisified__';
const IGNORED_PROPS = /^(?:length|name|arguments|caller|callee|prototype|__isPromisified__)$/;

/**
 * thatLooksLikeAPromiseToMe()
 *
 * Duck-types a promise.
 *
 * @param {object} o
 * @return {bool} True if this resembles a promise
 */
function thatLooksLikeAPromiseToMe(o) {
  return o && typeof o.then === "function" && typeof o.catch === "function";
}

function isPromisified(fn) {
  try {
    return fn[MAGIC_KEY] === true;
  } catch (e) {
    return false;
  }
}

/**
 * promisify()
 *
 * Transforms callback-based function -- func(arg1, arg2 .. argN, callback) -- into
 * an ES6-compatible Promise. Promisify provides a default callback of the form (error, result)
 * and rejects when `error` is truthy. You can also supply settings object as the second argument.
 *
 * @param {function} original - The function to promisify
 * @param {object} settings - Settings object
 * @param {object} settings.thisArg - A `this` context to use. If not set, assume `settings` _is_ `thisArg`
 * @param {bool} settings.multiArgs - Should multiple arguments be returned as an array?
 * @return {function} A promisified version of `original`
 */
function promisify(original, settings) {
  return function promiseWrapper(...args) {
    const returnMultipleArguments = settings && settings.multiArgs;
    let target;
    if (settings && settings.thisArg) {
      target = settings.thisArg;
    } else if (settings) {
      target = settings;
    }

    // Return the promisified function
    return new Promise(function promisified(resolve, reject) {
      // Append the callback bound to the context
      args.push(function callback(err, ...values) {
        if (err) {
          reject(err);
          return;
        }

        if (!!returnMultipleArguments === false) {
          resolve(values[0]);
          return;
        }

        resolve(values);
      });

      // Call the function
      const response = original.apply(target, args);

      // If it looks like original already returns a promise,
      // then just resolve with that promise. Hopefully, the callback function we added will just be ignored.
      if (thatLooksLikeAPromiseToMe(response)) {
        resolve(response);
      }
    });
  };
}

function promisifyAll(target) {
  Object.getOwnPropertyNames(target).forEach((key) => {
    const descriptor = Object.getOwnPropertyDescriptor(target, key);

    if (typeof descriptor.value !== 'function') {
      return;
    }
    if (IGNORED_PROPS.test(key)) {
      return;
    }
    if (isPromisified(target[key])) {
      return;
    }

    const promisifiedKey = `${key}Async`;

    target[promisifiedKey] = promisify(target[key]);

    [key, promisifiedKey].forEach((rkey) => {
      Object.defineProperty(target[rkey], MAGIC_KEY, {
        value: true,
        configurable: true,
        enumerable: false,
        writable: true,
      });
    });
  });

  return target;
}

async function each(items, fn) {
  const results = [];
  for (const item of items) {
    results.push(await fn(item));
  }
  return results;
}

function props(obj) {
  const awaitables = [];
  const keys = Object.keys(obj);
  for (const key of keys) {
    awaitables.push(obj[key]);
  }
  return Promise.all(awaitables).then(function r(results) {
    const byName = {};
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      byName[key] = results[i];
    }
    return byName;
  });
}

async function getState() {
  const t = {};
  return await Promise.race([this, t]).then(v =>
    ((v === t) ? "pending" : "fulfilled")
  , () => "rejected");
}

async function isResolved() {
  return await this.getState() === "fulfilled";
}

async function isRejected() {
  return await this.getState() === "rejected";
}

global.Promise.prototype.getState = getState;
global.Promise.prototype.isResolved = isResolved;
global.Promise.prototype.isRejected = isRejected;

global.Promise.each = each;
global.Promise.props = props;
global.Promise.promisify = promisify;
global.Promise.promisifyAll = promisifyAll;

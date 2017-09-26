/* eslint no-prototype-builtins: 0 */
import _ from 'underscore';
import moment from 'moment-timezone';
// On import this will extend the `moment` object
import 'moment-round';

import TestConstants from './test-constants';

export function waitsForPromise(...args) {
  let shouldReject;
  let timeout;
  if (args.length > 1) {
    shouldReject = args[0].shouldReject;
    timeout = args[0].timeout;
  } else {
    shouldReject = false;
  }
  const fn = _.last(args);

  return window.waitsFor(timeout, moveOn => {
    const promise = fn();
    // Keep in mind we can't check `promise instanceof Promise` because parts of
    // the app still use other Promise libraries Just see if it looks
    // promise-like.
    if (!promise || !promise.then) {
      jasmine
        .getEnv()
        .currentSpec.fail(
          `Expected callback to return a promise-like object, but it returned ${promise}`
        );
      return moveOn();
    } else if (shouldReject) {
      promise.catch(moveOn);
      return promise.then(() => {
        jasmine.getEnv().currentSpec.fail('Expected promise to be rejected, but it was resolved');
        return moveOn();
      });
    }

    promise.then(moveOn);
    return promise.catch(error => {
      // I don't know what `pp` does, but for standard `new Error` objects,
      // it sometimes returns "{  }". Catch this case and fall through to toString()
      let msg = jasmine.pp(error);
      if (msg === '{  }') {
        msg = error.toString();
      }
      jasmine
        .getEnv()
        .currentSpec.fail(`Expected promise to be resolved, but it was rejected with ${msg}`);
      return moveOn();
    });
  });
}

export function toHaveLength(expected) {
  if (this.actual == null) {
    this.message = () => `Expected object ${this.actual} has no length method`;
    return false;
  }
  const notText = this.isNot ? ' not' : '';
  this.message = () =>
    `Expected object with length ${this.actual.length} to${notText} have length ${expected}`;
  return this.actual.length === expected;
}

export function unspy(object, methodName) {
  if (!object[methodName].hasOwnProperty('originalValue')) {
    throw new Error('Not a spy');
  }
  object[methodName] = object[methodName].originalValue;
}

export function attachToDOM(element) {
  const jasmineContent = document.querySelector('#jasmine-content');
  if (!jasmineContent.contains(element)) {
    jasmineContent.appendChild(element);
  }
}

// This date was chosen because it's close to a DST boundary
export function testNowMoment() {
  return moment.tz('2016-03-15 12:00', TestConstants.TEST_TIME_ZONE);
}

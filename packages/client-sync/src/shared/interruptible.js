const {EventEmitter} = require('events')
const {Errors} = require('isomorphic-core')

/**
 * Interruptible objects allow you to run and interrupt functions by using
 * generator functions (https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/function*).
 *
 * In order to indicate where a generator function can be interrupted, you must use the
 * keyword `yield` instead of `await` to wait for the resolution of Promises.
 *
 * e.g.
 * ```
 * const interruptible = new Interruptible()
 *
 * async * interruptibleFunc(db) {
 *   // Use `yield` to indicate that we can interrupt the function after
 *   // this async operation has resolved
 *   const models = yield db.Messages.findAll()
 *
 *   // If the operation is interrupted, code execution will stop here!
 *
 *   // ...
 *
 *   await saveModels(models)
 *   // `await` wont stop code execution even if operation is interrupted
 *
 *   // ...
 * }
 *
 * await interruptible.run(interruptibleFunc, this, db)
 *
 * // Sometime later
 * interruptible.interrupt()
 * ```
 */
class Interruptible extends EventEmitter {
  constructor() {
    super()
    this._interrupt = false
    this._running = false
    this._rejectWithinRun = null
  }

  interrupt({forceReject = false} = {}) {
    if (!this._running) { return Promise.resolve() }

    // Start listening before the interrupt, so we don't miss the 'interrupted' event
    const promise = new Promise((resolve) => this.once('interrupted', resolve))
    this._interrupt = true

    if (forceReject && this._rejectWithinRun) {
      // This will reject the `interruptible.run()` call and immediately return
      // control to the code path that is awaiting it.
      this._rejectWithinRun(new Errors.RetryableError('Forcefully interrupted'))
    }

    return promise
  }

  // This function executes the generator object through completion or until we
  // are interrupted
  _runGenerator(generatorObj) {
    return new Promise(async (resolve, reject) => {
      try {
        if (!generatorObj || typeof generatorObj.next !== 'function') {
          throw new Error('Interruptible: You must pass a generator function to run')
        }
        let step = {done: false};
        let val;
        const advance = async () => {
          // Calling generator.next() will execute the generator function until
          // it's next `yield` statement.
          // The return value of next is an object with the following shape:
          // {
          //   value: 'some val', // `yield`ed value
          //   done: false,       // is execution done?
          // }
          step = generatorObj.next(val)

          if (typeof step.then === 'function') {
            // Await it in case it is a promise.
            step = await step
          }

          if (!step.value) {
            // If no value, just continue advancing
            val = step.value
            return
          }


          if (typeof step.value.next === 'function') {
            // step.value is a generator object, so let's run it recursively
            val = await this._runGenerator(step.value)
          } else {
            // step.value could be a Promise or not, let's just `await` it
            // anyway
            val = await step.value
          }
          return
        }

        // Advance until done
        while (!step.done) {
          if (this._interrupt) {
            this.emit('interrupted')
            console.log('Operation Interrupted')
            return resolve()
          }
          await advance()
        }
        return resolve(val)
      } catch (err) {
        return reject(err)
      }
    })
  }

  /**
   * @returns a Promise that resolves when the generator function has been
   * executed to completion, or when it has been interrupted. It will reject if
   * the generator function throws an error at any point.
   */
  async run(generatorFunc, ctx, ...fnArgs) {
    this._running = true
    const generatorObj = generatorFunc.call(ctx, ...fnArgs)
    const response = await new Promise(async (resolve, reject) => {
      this._rejectWithinRun = (rejectValue) => {
        reject(rejectValue)
      }
      let _response;
      try {
        _response = await this._runGenerator(generatorObj)
      } catch (err) {
        reject(err)
        return;
      }
      resolve(_response)
    })
    this._interrupt = false
    this._running = false
    return response
  }
}

module.exports = Interruptible

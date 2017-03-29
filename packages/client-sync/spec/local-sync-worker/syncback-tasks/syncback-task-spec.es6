import {Errors} from 'isomorphic-core'
import {createLogger} from '../../../src/shared/logger'
import SyncbackTask from '../../../src/local-sync-worker/syncback-tasks/syncback-task'

let syncbackTask;
const TIMEOUT_DELAY = 10;
let fakeSetTimeout;

describe("SyncbackTask", () => {
  beforeEach(() => {
    global.Logger = createLogger()
    const account = {id: 'account1'}
    const syncbackRequest = {
      status: 'NEW',
    }
    syncbackTask = new SyncbackTask(account, syncbackRequest)
    fakeSetTimeout = window.setTimeout
    window.setTimeout = window.originalSetTimeout
  })
  afterEach(() => {
    window.setTimeout = fakeSetTimeout;
  })
  describe("when it takes too long", () => {
    beforeEach(() => {
      syncbackTask._run = function* hello() {
        yield new Promise((resolve) => {
          setTimeout(resolve, TIMEOUT_DELAY + 5)
        })
      }
    })

    it("is stopped if retryable", async () => {
      syncbackTask._syncbackRequest.status = "INPROGRESS-RETRYABLE"
      let error;
      try {
        await syncbackTask.run({timeoutDelay: TIMEOUT_DELAY})
      } catch (err) {
        error = err
      }
      expect(error).toBeDefined()
      expect(error instanceof Errors.RetryableError).toEqual(true)
      expect(/interrupted/i.test(error.toString())).toEqual(true)
    })

    it("is not stopped if not retryable", async () => {
      syncbackTask._syncbackRequest.status = "INPROGRESS-NOTRETRYABLE"
      // If this does end up being stopped, it'll throw an error.
      await syncbackTask.run({timeoutDelay: TIMEOUT_DELAY})
    })
  })
})

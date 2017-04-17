import {ipcRenderer} from 'electron'
import {IdentityStore, AccountStore, Actions, NylasAPI, NylasAPIRequest} from 'nylas-exports'

const CHECK_HEALTH_INTERVAL = 5 * 60 * 1000;

class SyncHealthChecker {
  constructor() {
    this._lastSyncActivity = null
    this._interval = null
  }

  start() {
    if (this._interval) {
      console.warn('SyncHealthChecker has already been started')
    } else {
      this._interval = setInterval(this._checkSyncHealth, CHECK_HEALTH_INTERVAL)
    }
  }

  stop() {
    clearInterval(this._interval)
    this._interval = null
  }

  // This is a separate function so the request can be manipulated in the specs
  _buildRequest = () => {
    return new NylasAPIRequest({
      api: NylasAPI,
      options: {
        accountId: AccountStore.accounts()[0].id,
        path: `/health`,
      },
    });
  }

  _checkSyncHealth = async () => {
    try {
      if (!IdentityStore.identity()) {
        return
      }
      const request = this._buildRequest()
      const response = await request.run()
      this._lastSyncActivity = response
    } catch (err) {
      if (/ECONNREFUSED/i.test(err.toString())) {
        this._onWorkerWindowUnavailable()
      } else {
        err.message = `Error checking sync health: ${err.message}`
        NylasEnv.reportError(err)
      }
    }
  }

  _onWorkerWindowUnavailable() {
    let extraData = {};

    // Extract data that we want to report. We'll report the entire
    // _lastSyncActivity object, but it'll probably be useful if we can segment
    // by the data in the oldest or newest entry, so we report those as
    // individual values too.
    const lastActivityEntries = Object.entries(this._lastSyncActivity || {})
    if (lastActivityEntries.length > 0) {
      const times = lastActivityEntries.map((entry) => entry[1].time)
      const now = Date.now()

      const maxTime = Math.max(...times)
      const mostRecentEntry = lastActivityEntries.find((entry) => entry[1].time === maxTime)
      const [mostRecentActivityAccountId, {
        activity: mostRecentActivity,
        time: mostRecentActivityTime,
      }] = mostRecentEntry;
      const mostRecentDuration = now - mostRecentActivityTime

      const minTime = Math.min(...times)
      const leastRecentEntry = lastActivityEntries.find((entry) => entry[1].time === minTime)
      const [leastRecentActivityAccountId, {
        activity: leastRecentActivity,
        time: leastRecentActivityTime,
      }] = leastRecentEntry;
      const leastRecentDuration = now - leastRecentActivityTime

      extraData = {
        mostRecentActivity,
        mostRecentActivityTime,
        mostRecentActivityAccountId,
        mostRecentDuration,
        leastRecentActivity,
        leastRecentActivityTime,
        leastRecentActivityAccountId,
        leastRecentDuration,
      }
    }

    NylasEnv.reportError(new Error('Worker window was unavailable'), {
      // This information isn't as useful in Sentry, but include it here until
      // the data is actually sent to Mixpanel. (See the TODO below)
      lastActivityPerAccount: this._lastSyncActivity,
      ...extraData,
    })

    // TODO: This doesn't make it to Mixpanel because our analytics process
    // lives in the worker window. We should move analytics to the main process.
    // https://phab.nylas.com/T8029
    Actions.recordUserEvent('Worker Window Unavailable', {
      lastActivityPerAccount: this._lastSyncActivity,
      ...extraData,
    })

    console.log(`Detected worker window was unavailable. Restarting it.`, this._lastSyncActivity)
    ipcRenderer.send('ensure-worker-window')
  }
}

export default new SyncHealthChecker()

import isOnline from 'is-online'
import NylasStore from 'nylas-store'
import {ExponentialBackoffScheduler} from 'isomorphic-core'
import Actions from '../actions'


const CHECK_ONLINE_INTERVAL = 30 * 1000

class OnlineStatusStore extends NylasStore {

  constructor() {
    super()
    this._isOnline = true
    this._retryingInSeconds = 0
    this._countdownInterval = null
    this._checkOnlineTimeout = null
    this._backoffScheduler = new ExponentialBackoffScheduler({jitter: false})

    this.setupEmitter()

    if (NylasEnv.isMainWindow()) {
      Actions.checkOnlineStatus.listen(() => this._checkOnlineStatus())
      this._checkOnlineStatus()
    }
  }

  isOnline() {
    return this._isOnline
  }

  retryingInSeconds() {
    return this._retryingInSeconds
  }

  async _setNextOnlineState() {
    const nextIsOnline = await isOnline()
    if (this._isOnline !== nextIsOnline) {
      this._isOnline = nextIsOnline
      this.trigger()
    }
  }

  async _checkOnlineStatus() {
    this._clearCheckOnlineInterval()
    this._clearRetryCountdown()

    // If we are currently offline, this trigger will show the `Retrying now...`
    // message
    this._retryingInSeconds = 0
    this.trigger()

    await this._setNextOnlineState()

    if (!this._isOnline) {
      this._checkOnlineStatusAfterBackoff()
    } else {
      this._backoffScheduler.reset()
      this._checkOnlineTimeout = setTimeout(() => {
        this._checkOnlineStatus()
      }, CHECK_ONLINE_INTERVAL)
    }
  }

  async _checkOnlineStatusAfterBackoff() {
    const nextDelayMs = this._backoffScheduler.nextDelay()
    try {
      await this._countdownRetryingInSeconds(nextDelayMs)
      this._checkOnlineStatus()
    } catch (err) {
      // This means the retry countdown was cleared, in which case we don't
      // want to do anything
    }
  }

  async _countdownRetryingInSeconds(nextDelayMs) {
    this._retryingInSeconds = Math.ceil(nextDelayMs / 1000)
    this.trigger()

    return new Promise((resolve, reject) => {
      this._clearRetryCountdown()
      this._emitter.once('clear-retry-countdown', () => reject(new Error('Retry countdown cleared')))

      this._countdownInterval = setInterval(() => {
        this._retryingInSeconds = Math.max(0, this._retryingInSeconds - 1)
        this.trigger()

        if (this._retryingInSeconds === 0) {
          this._clearCountdownInterval()
          resolve()
        }
      }, 1000)
    })
  }

  _clearCheckOnlineInterval() {
    clearInterval(this._checkOnlineTimeout)
    this._checkOnlineTimeout = null
  }

  _clearCountdownInterval() {
    clearInterval(this._countdownInterval)
    this._countdownInterval = null
  }

  _clearRetryCountdown() {
    this._clearCountdownInterval()
    this._emitter.emit('clear-retry-countdown')
  }
}

export default new OnlineStatusStore()

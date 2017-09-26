import MailspringStore from 'mailspring-store';
import { ExponentialBackoffScheduler } from '../../backoff-schedulers';
import Actions from '../actions';

let isOnlineModule = null;

const CHECK_ONLINE_INTERVAL = 30 * 1000;

class OnlineStatusStore extends MailspringStore {
  constructor() {
    super();
    this._online = true;
    this._countdownSeconds = 0;

    this._interval = null;
    this._timeout = null;
    this._backoffScheduler = new ExponentialBackoffScheduler({ jitter: false });

    if (AppEnv.isMainWindow()) {
      Actions.checkOnlineStatus.listen(this._checkOnlineStatus);
      setTimeout(this._checkOnlineStatus, 3 * 1000); // initial check
    }
  }

  isOnline() {
    return this._online;
  }

  retryingInSeconds() {
    return this._countdownSeconds;
  }

  async _setNextOnlineState() {
    isOnlineModule = isOnlineModule || require('is-online'); //eslint-disable-line

    const nextIsOnline = await isOnlineModule();
    if (this._online !== nextIsOnline) {
      this._online = nextIsOnline;
      this.trigger({ onlineDidChange: true, countdownDidChange: false });
    }
  }

  _checkOnlineStatus = async () => {
    clearInterval(this._interval);
    clearTimeout(this._timeout);

    // If we are currently offline, this trigger will show `Retrying now...`
    this._countdownSeconds = 0;
    this.trigger({ onlineDidChange: false, countdownDidChange: true });

    await this._setNextOnlineState();

    if (this._online) {
      // just check again later
      this._backoffScheduler.reset();
      this._timeout = setTimeout(this._checkOnlineStatus, CHECK_ONLINE_INTERVAL);
    } else {
      // count down an inreasing delay and check again
      this._countdownSeconds = Math.ceil(this._backoffScheduler.nextDelay() / 1000);
      this._interval = setInterval(() => {
        this._countdownSeconds = Math.max(0, this._countdownSeconds - 1);
        if (this._countdownSeconds === 0) {
          this._checkOnlineStatus();
        } else {
          this.trigger({ onlineDidChange: false, countdownDidChange: true });
        }
      }, 1000);
    }
  };
}

export default new OnlineStatusStore();

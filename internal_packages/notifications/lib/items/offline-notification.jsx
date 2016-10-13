import {NylasSyncStatusStore, React, Actions} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

export default class OfflineNotification extends React.Component {
  static displayName = 'OfflineNotification';
  static containerRequired = false;

  constructor() {
    super();
    this._updateInterval = null;
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unlisten = NylasSyncStatusStore.listen(() => {
      const nextState = this.getStateFromStores();
      if ((nextState.connected !== this.state.connected) || (nextState.nextRetryText !== this.state.nextRetryText)) {
        this.setState(nextState);
      }
    });

    window.addEventListener('browser-window-focus', this.onWindowFocusChanged);
    window.addEventListener('browser-window-blur', this.onWindowFocusChanged);
    this.ensureCountdownInterval();
  }

  componentDidUpdate() {
    this.ensureCountdownInterval();
  }

  componentWillUnmount() {
    window.removeEventListener('browser-window-focus', this.onWindowFocusChanged);
    window.removeEventListener('browser-window-blur', this.onWindowFocusChanged);
  }

  onTryAgain = () => {
    Actions.retrySync();
  }

  onWindowFocusChanged = () => {
    this.setState(this.getStateFromStores());
    this.ensureCountdownInterval();
  }

  getStateFromStores() {
    const nextRetryDelay = NylasSyncStatusStore.nextRetryDelay();
    const nextRetryTimestamp = NylasSyncStatusStore.nextRetryTimestamp();
    let connected = NylasSyncStatusStore.connected();

    if (nextRetryDelay < 5000) {
      connected = true;
    }

    let nextRetryText = null;
    if (!connected) {
      if (document.body.classList.contains('is-blurred')) {
        nextRetryText = 'soon';
      } else {
        const seconds = Math.ceil((nextRetryTimestamp - Date.now()) / 1000.0);
        if (seconds > 1) {
          nextRetryText = `in ${seconds} seconds`;
        } else {
          nextRetryText = `now`;
        }
      }
    }

    return {connected, nextRetryText};
  }

  ensureCountdownInterval = () => {
    if (this._updateInterval) {
      clearInterval(this._updateInterval);
    }
    // only count down the "Reconnecting in..." label if the window is in the
    // foreground to avoid the battery hit.
    if (!this.state.connected && !document.body.classList.contains('is-blurred')) {
      this._updateInterval = setInterval(() => {
        this.setState(this.getStateFromStores());
      }, 1000);
    }
  }

  render() {
    const {connected, nextRetryText} = this.state;
    if (connected) {
      return <span />
    }

    return (
      <Notification
        title="Nylas N1 is offline"
        priority="5"
        icon="volstead-offline.png"
        subtitle={`Trying again ${nextRetryText}`}
        actions={[{label: 'Try now', id: 'try_now', fn: this.onTryAgain}]}
      />
    )
  }
}

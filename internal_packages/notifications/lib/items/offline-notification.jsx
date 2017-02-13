import {NylasSyncStatusStore, React, Actions} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

const DISCONNECT_DEBOUNCE_INTERVAL = 15000;
const CHECK_STATUS_INTERVAL = 3000

export default class OfflineNotification extends React.Component {
  static displayName = 'OfflineNotification';

  constructor() {
    super();
    this._updateInterval = null;
    this._setOfflineTimeout = null;
    this._setRetryingTimeout = null;
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unlisten = NylasSyncStatusStore.listen(this.onConnectedStatusChanged);

    window.addEventListener('browser-window-focus', this.onWindowFocusChanged);
    window.addEventListener('browser-window-blur', this.onWindowFocusChanged);
    this.ensureCountdownInterval();
  }

  componentDidUpdate() {
    this.ensureCountdownInterval();
  }

  componentWillUnmount() {
    this.unlisten();
    window.removeEventListener('browser-window-focus', this.onWindowFocusChanged);
    window.removeEventListener('browser-window-blur', this.onWindowFocusChanged);
  }

  onConnectedStatusChanged = () => {
    const nextState = this.getStateFromStores();
    if (this.state.connected) {
      if (!nextState.connected && !this._setOfflineTimeout) {
        this._setOfflineTimeout = setTimeout(this._didBecomeDisconnected, DISCONNECT_DEBOUNCE_INTERVAL);
      }
      return;
    }

    if (nextState.connected) {
      this._didBecomeConnected();
    }
  }

  onTryAgain = () => {
    clearTimeout(this._setRetryingTimeout)
    this.setState({retrying: true})
    this._setRetryingTimeout = setTimeout(() => this.setState({retrying: false}), 2000)
    Actions.retryDeltaConnection();
  }

  onWindowFocusChanged = () => {
    const nextState = this.getStateFromStores();
    // If we notice we've reconnected we want to immediately remove the notification.
    if (nextState.connected && !this.state.connected) {
      this._didBecomeConnected();
      return;
    }
    this.ensureCountdownInterval();
  }

  getStateFromStores() {
    return {connected: NylasSyncStatusStore.connected()};
  }

  _clearOfflineTimeout = () => {
    if (this._setOfflineTimeout) {
      clearTimeout(this._setOfflineTimeout);
      this._setOfflineTimeout = null;
    }
  }

  _clearUpdateInterval = () => {
    if (this._updateInterval) {
      clearInterval(this._updateInterval);
      this._updateInterval = null;
    }
  }

  _didBecomeConnected = () => {
    this._clearOfflineTimeout();
    this._clearUpdateInterval();
    this.setState({connected: true});
  }

  _didBecomeDisconnected = () => {
    this._clearOfflineTimeout();
    // We will call ensureCountdownInterval() in componentDidUpdate when this
    // setState is complete.
    this.setState({connected: false});
  }

  ensureCountdownInterval = () => {
    this._clearUpdateInterval();

    // only attempt to retry if the window is in the foreground to avoid
    // the battery hit.
    if (!this.state.connected && !document.body.classList.contains('is-blurred')) {
      Actions.retryDeltaConnection();
      this._updateInterval = setInterval(() => {
        Actions.retryDeltaConnection();
      }, CHECK_STATUS_INTERVAL);
    }
  }

  render() {
    const {connected, retrying} = this.state;
    if (connected) {
      return <span />;
    }
    const tryLabel = retrying ? 'Retrying...' : 'Try now';

    return (
      <Notification
        className="offline"
        title="Nylas Mail is offline"
        priority="5"
        icon="volstead-offline.png"
        actions={[{label: tryLabel, id: 'try_now', fn: this.onTryAgain}]}
      />
    )
  }
}

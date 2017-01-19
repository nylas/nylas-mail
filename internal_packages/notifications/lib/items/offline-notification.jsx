import {NylasSyncStatusStore, React, Actions} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';


const CHECK_STATUS_INTERVAL = 5000

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
    window.removeEventListener('browser-window-focus', this.onWindowFocusChanged);
    window.removeEventListener('browser-window-blur', this.onWindowFocusChanged);
  }

  onConnectedStatusChanged = () => {
    const nextState = this.getStateFromStores();
    if ((nextState.connected !== this.state.connected)) {
      clearTimeout(this._setOfflineTimeout)

      if (nextState.connected) {
        this.setState(nextState);
      } else {
        // Only set the status to offline if we are still offline after a while
        // This prevents the notification from flickering
        this._setOfflineTimeout = setTimeout(this.onConnectedStatusChanged, 3 * CHECK_STATUS_INTERVAL)
      }
    }
  }

  onTryAgain = () => {
    clearTimeout(this._setRetryingTimeout)
    this.setState({retrying: true})
    this._setRetryingTimeout = setTimeout(() => this.setState({retrying: false}), 2000)
    Actions.retryDeltaConnection();
  }

  onWindowFocusChanged = () => {
    this.setState(this.getStateFromStores());
    this.ensureCountdownInterval();
  }

  getStateFromStores() {
    return {connected: NylasSyncStatusStore.connected()};
  }

  ensureCountdownInterval = () => {
    clearInterval(this._updateInterval);

    // only attempt to retry if the window is in the foreground to avoid
    // the battery hit.
    if (!this.state.connected && !document.body.classList.contains('is-blurred')) {
      this._updateInterval = setInterval(() => {
        Actions.retryDeltaConnection();
      }, CHECK_STATUS_INTERVAL);
    }
  }

  render() {
    const {connected, retrying} = this.state;
    if (connected) {
      return <span />
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

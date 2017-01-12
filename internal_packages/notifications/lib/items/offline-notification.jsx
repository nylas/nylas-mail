import {NylasSyncStatusStore, React, Actions} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

export default class OfflineNotification extends React.Component {
  static displayName = 'OfflineNotification';

  constructor() {
    super();
    this._updateInterval = null;
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unlisten = NylasSyncStatusStore.listen(() => {
      const nextState = this.getStateFromStores();
      if ((nextState.connected !== this.state.connected)) {
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
    const {connected} = this.state;
    if (connected) {
      return <span />
    }

    return (
      <Notification
        className="offline"
        title="Nylas N1 is offline"
        priority="5"
        icon="volstead-offline.png"
        actions={[{label: 'Try now', id: 'try_now', fn: this.onTryAgain}]}
      />
    )
  }
}

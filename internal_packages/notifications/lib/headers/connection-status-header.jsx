import {NylasSyncStatusStore, React, Actions} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

export default class ConnectionStatusHeader extends React.Component {
  static displayName = 'ConnectionStatusHeader';

  constructor() {
    super();
    this._updateInterval = null;
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unsubscribe = NylasSyncStatusStore.listen(()=> {
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
    const nextRetryTimestamp = NylasSyncStatusStore.nextRetryTimestamp();
    const connected = NylasSyncStatusStore.connected();

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
      return (<span/>);
    }

    return (
      <div className="connection-status-header notifications-sticky">
        <div className={"notifications-sticky-item notification-offline"}>
          <RetinaImg
            className="icon"
            name="icon-alert-onred.png"
            mode={RetinaImg.Mode.ContentPreserve} />
          <div className="message">
            Nylas N1 isn't able to reach api.nylas.com. Retrying {nextRetryText}.
          </div>
          <a className="action default" onClick={this.onTryAgain}>
            Try Again Now
          </a>
        </div>
      </div>
    );
  }
}

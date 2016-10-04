import {React, LaunchServices} from 'nylas-exports';
import Notification from '../notification';

const SETTINGS_KEY = 'nylas.mailto.prompted-about-default'

export default class DefaultClientNotification extends React.Component {
  static displayName = 'DefaultClientNotification';
  static containerRequired = false;

  constructor() {
    super();
    this.services = new LaunchServices();
    this.state = this.getStateFromStores();
    this.state.initializing = true;
    this.mounted = false;
  }

  componentDidMount() {
    this.mounted = true;
    this.services.isRegisteredForURLScheme('mailto', (registered) => {
      if (this.mounted) {
        this.setState({
          initializing: false,
          registered: registered,
        })
      }
    })
    this.disposable = NylasEnv.config.onDidChange(SETTINGS_KEY,
      () => this.setState(this.getStateFromStores()));
  }

  componentWillUnmount() {
    this.mounted = false;
    this.disposable.dispose();
  }

  getStateFromStores() {
    return {
      alreadyPrompted: NylasEnv.config.get(SETTINGS_KEY),
    }
  }

  _onAccept = () => {
    this.services.registerForURLScheme('mailto', (err) => {
      if (err) {
        NylasEnv.reportError(err)
      }
    });
    NylasEnv.config.set(SETTINGS_KEY, true)
  }

  _onDecline = () => {
    NylasEnv.config.set(SETTINGS_KEY, true)
  }

  render() {
    if (this.state.initializing || this.state.alreadyPrompted || this.state.registered) {
      return <span />
    }
    return (
      <Notification
        title="Would you like to make N1 your default mail client?"
        priority="1"
        icon="volstead-defaultclient.png"
        actions={[{
          label: "Yes",
          fn: this._onAccept,
        }, {
          label: "No",
          fn: this._onDecline,
        }]}
      />
    )
  }
}

import { React, DefaultClientHelper } from 'mailspring-exports';
import { Notification } from 'mailspring-component-kit';

const SETTINGS_KEY = 'mailto.prompted-about-default';

export default class DefaultClientNotification extends React.Component {
  static displayName = 'DefaultClientNotification';

  constructor() {
    super();
    this.helper = new DefaultClientHelper();
    this.state = this.getStateFromStores();
    this.state.initializing = true;
    this.mounted = false;
  }

  componentDidMount() {
    this.mounted = true;
    this.helper.isRegisteredForURLScheme('mailto', registered => {
      if (this.mounted) {
        this.setState({
          initializing: false,
          registered: registered,
        });
      }
    });
    this.disposable = AppEnv.config.onDidChange(SETTINGS_KEY, () =>
      this.setState(this.getStateFromStores())
    );
  }

  componentWillUnmount() {
    this.mounted = false;
    this.disposable.dispose();
  }

  getStateFromStores() {
    return {
      alreadyPrompted: AppEnv.config.get(SETTINGS_KEY),
    };
  }

  _onAccept = () => {
    this.helper.registerForURLScheme('mailto', err => {
      if (err) {
        AppEnv.reportError(err);
      }
    });
    AppEnv.config.set(SETTINGS_KEY, true);
  };

  _onDecline = () => {
    AppEnv.config.set(SETTINGS_KEY, true);
  };

  render() {
    if (this.state.initializing || this.state.alreadyPrompted || this.state.registered) {
      return <span />;
    }
    return (
      <Notification
        title="Would you like to make Mailspring your default mail client?"
        priority="1"
        icon="volstead-defaultclient.png"
        actions={[
          {
            label: 'Yes',
            fn: this._onAccept,
          },
          {
            label: 'No',
            fn: this._onDecline,
          },
        ]}
      />
    );
  }
}

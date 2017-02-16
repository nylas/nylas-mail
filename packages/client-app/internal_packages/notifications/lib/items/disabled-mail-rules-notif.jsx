import {React, MailRulesStore, Actions} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

export default class DisabledMailRulesNotification extends React.Component {
  static displayName = 'DisabledMailRulesNotification';

  constructor() {
    super();
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unlisten = MailRulesStore.listen(() => this.setState(this.getStateFromStores()));
  }

  componentWillUnmount() {
    this.unlisten();
  }

  getStateFromStores() {
    return {
      disabledRules: MailRulesStore.disabledRules(),
    }
  }

  _onOpenMailRulesPreferences = () => {
    Actions.switchPreferencesTab('Mail Rules', {accountId: this.state.disabledRules[0].accountId})
    Actions.openPreferences()
  }

  render() {
    if (this.state.disabledRules.length === 0) {
      return <span />
    }
    return (
      <Notification
        priority="2"
        title="One or more of your mail rules have been disabled."
        icon="volstead-defaultclient.png"
        isError
        actions={[{
          label: 'View Mail Rules',
          fn: this._onOpenMailRulesPreferences,
        }]}
      />
    )
  }
}

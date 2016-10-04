import {shell, ipcRenderer} from 'electron';
import {React, Account, AccountStore, Actions, IdentityStore} from 'nylas-exports';
import Notification from '../notification';

export default class AccountErrorNotification extends React.Component {
  static displayName = 'AccountErrorNotification';
  static containerRequired = false;

  constructor() {
    super();
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unlisten = AccountStore.listen(() => this.setState(this.getStateFromStores()));
  }

  componentWillUnmount() {
    this.unlisten();
  }

  getStateFromStores() {
    return {
      accounts: AccountStore.accounts(),
    }
  }

  _onContactSupport = () => {
    shell.openExternal("https://support.nylas.com/hc/en-us/requests/new");
  }

  _onReconnect = (existingAccount) => {
    ipcRenderer.send('command', 'application:add-account', {existingAccount});
  }

  _onOpenAccountPreferences = () => {
    Actions.switchPreferencesTab('Accounts');
    Actions.openPreferences()
  }

  _onCheckAgain = () => {
    return IdentityStore.refreshIdentityAndAccounts();
  }

  render() {
    const erroredAccounts = this.state.accounts.filter(a => a.hasSyncStateError());
    let title;
    let subtitle;
    let subtitleAction;
    let actions;
    if (erroredAccounts.length === 0) {
      return <span />
    } else if (erroredAccounts.length > 1) {
      title = "Several of your accounts are having issues";
      actions = [{
        label: "Check Again",
        fn: this._onCheckAgain,
      }, {
        label: "Manage",
        fn: this._onOpenAccountPreferences,
      }];
    } else {
      const erroredAccount = erroredAccounts[0];
      switch (erroredAccount.syncState) {
        case Account.SYNC_STATE_AUTH_FAILED:
          title = `Cannot authenticate with ${erroredAccount.emailAddress}`;
          actions = [{
            label: "Check Again",
            fn: this._onCheckAgain,
          }, {
            label: 'Reconnect',
            fn: () => this._onReconnect(erroredAccount),
          }];
          break;
        case Account.SYNC_STATE_STOPPED:
          title = `Sync has been disabled for ${erroredAccount.emailAddress}`;
          subtitle = "Contact support";
          subtitleAction = this._onContactSupport;
          actions = [{
            label: "Check Again",
            fn: this._onCheckAgain,
          }];
          break;
        default:
          title = `Encountered an error with ${erroredAccount.emailAddress}`;
          subtitle = "Contact support";
          subtitleAction = this._onContactSupport;
          actions = [{
            label: "Check Again",
            fn: this._onCheckAgain,
          }];
      }
    }

    return (
      <Notification
        priority="3"
        isError
        title={title}
        subtitle={subtitle}
        subtitleAction={subtitleAction}
        actions={actions}
        icon="volstead-error.png"
      />
    )
  }
}

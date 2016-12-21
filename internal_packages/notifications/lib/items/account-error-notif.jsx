import {shell, ipcRenderer} from 'electron';
import {React, Account, AccountStore, Actions} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

export default class AccountErrorNotification extends React.Component {
  static displayName = 'AccountErrorNotification';

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

  _onCheckAgain(account) {
    if (account) {
      Actions.wakeLocalSyncWorkerForAccount(account.id)
      return
    }
    const erroredAccounts = this.state.accounts.filter(a => a.hasSyncStateError());
    erroredAccounts.forEach(acc => Actions.wakeLocalSyncWorkerForAccount(acc.id))
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
        fn: () => this._onCheckAgain(),
      }, {
        label: "Manage",
        fn: this._onOpenAccountPreferences,
      }];
    } else {
      const erroredAccount = erroredAccounts[0];
      switch (erroredAccount.syncState) {
        case Account.SYNC_STATE_N1_CLOUD_AUTH_FAILED:
          title = `Cannot authenticate N1 Cloud Services with ${erroredAccount.emailAddress}`;
          actions = [{
            label: "Check Again",
            fn: () => this._onCheckAgain(erroredAccount),
          }, {
            label: 'Reconnect',
            fn: () => this._onReconnect(erroredAccount),
          }];
          break;
        case Account.SYNC_STATE_AUTH_FAILED:
          title = `Cannot authenticate with ${erroredAccount.emailAddress}`;
          actions = [{
            label: "Check Again",
            fn: () => this._onCheckAgain(erroredAccount),
          }, {
            label: 'Reconnect',
            fn: () => this._onReconnect(erroredAccount),
          }];
          break;
        default:
          title = `Encountered an error while syncing ${erroredAccount.emailAddress}`;
          subtitle = "Contact support";
          subtitleAction = this._onContactSupport;
          actions = [{
            label: "Check Again",
            fn: () => this._onCheckAgain(erroredAccount),
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

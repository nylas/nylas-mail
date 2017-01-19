import {shell, ipcRenderer} from 'electron';
import {React, Account, AccountStore, Actions} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

export default class AccountErrorNotification extends React.Component {
  static displayName = 'AccountErrorNotification';

  constructor() {
    super();
    this._checkingTimeout = null
    this.state = {
      checking: false,
      debugKeyPressed: false,
      accounts: AccountStore.accounts(),
    }
  }

  componentDidMount() {
    this.unlisten = AccountStore.listen(() => this.setState({
      accounts: AccountStore.accounts(),
    }));
  }

  componentWillUnmount() {
    this.unlisten();
  }

  _onContactSupport = (erroredAccount) => {
    let url = 'https://support.nylas.com/hc/en-us/requests/new'
    if (erroredAccount) {
      url += `?email=${encodeURIComponent(erroredAccount.emailAddress)}`
      const {syncError} = erroredAccount
      if (syncError != null) {
        url += `&subject=${encodeURIComponent('Sync Error')}`
        const description = encodeURIComponent(
          `Sync Error:\n\`\`\`\n${JSON.stringify(syncError, null, 2)}\n\`\`\``
        )
        url += `&description=${description}`
      }
    }
    shell.openExternal(url);
  }

  _onReconnect = (existingAccount) => {
    ipcRenderer.send('command', 'application:add-account', {existingAccount});
  }

  _onOpenAccountPreferences = () => {
    Actions.switchPreferencesTab('Accounts');
    Actions.openPreferences()
  }

  _onCheckAgain(event, account) {
    if (event.metaKey) {
      Actions.debugSync()
      return
    }
    clearTimeout(this._checkingTimeout)
    this.setState({checking: true})
    this._checkingTimeout = setTimeout(() => this.setState({checking: false}), 10000)

    if (account) {
      Actions.wakeLocalSyncWorkerForAccount(account.id)
      return
    }
    const erroredAccounts = this.state.accounts.filter(a => a.hasSyncStateError());
    erroredAccounts.forEach(acc => Actions.wakeLocalSyncWorkerForAccount(acc.id))
  }

  render() {
    const erroredAccounts = this.state.accounts.filter(a => a.hasSyncStateError());
    const checkAgainLabel = this.state.checking ? 'Checking...' : 'Check Again'
    let title;
    let subtitle;
    let subtitleAction;
    let actions;
    if (erroredAccounts.length === 0) {
      return <span />
    } else if (erroredAccounts.length > 1) {
      title = "Several of your accounts are having issues";
      subtitle = "Contact support";
      subtitleAction = () => this._onContactSupport(erroredAccounts[0])
      actions = [{
        label: checkAgainLabel,
        fn: (e) => this._onCheckAgain(e),
      }, {
        label: "Manage",
        fn: this._onOpenAccountPreferences,
      }];
    } else {
      const erroredAccount = erroredAccounts[0];
      switch (erroredAccount.syncState) {
        case Account.SYNC_STATE_N1_CLOUD_AUTH_FAILED:
          title = `Cannot authenticate Nylas Mail Cloud Services with ${erroredAccount.emailAddress}`;
          actions = [{
            label: checkAgainLabel,
            fn: (e) => this._onCheckAgain(e, erroredAccount),
          }, {
            label: 'Reconnect',
            fn: () => this._onReconnect(erroredAccount),
          }];
          break;
        case Account.SYNC_STATE_AUTH_FAILED:
          title = `Cannot authenticate with ${erroredAccount.emailAddress}`;
          actions = [{
            label: checkAgainLabel,
            fn: (e) => this._onCheckAgain(e, erroredAccount),
          }, {
            label: 'Reconnect',
            fn: () => this._onReconnect(erroredAccount),
          }];
          break;
        default: {
          title = `Encountered an error while syncing ${erroredAccount.emailAddress}`;
          subtitle = "Contact support";
          subtitleAction = () => this._onContactSupport(erroredAccount)
          let label = this.state.checking ? 'Retrying...' : 'Try Again'
          if (this.state.debugKeyPressed) {
            label = 'Debug'
          }
          actions = [{
            label,
            fn: (e) => this._onCheckAgain(e, erroredAccount),
            props: {
              onMouseEnter: (e) => this.setState({debugKeyPressed: e.metaKey}),
              onMouseLeave: () => this.setState({debugKeyPressed: false}),
            },
          }];
        }
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

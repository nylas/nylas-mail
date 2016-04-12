import {AccountStore, Account, Actions, React} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'

export default class AccountErrorHeader extends React.Component {
  static displayName = 'AccountErrorHeader';

  constructor() {
    super();
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unsubscribe = AccountStore.listen(() => this._onAccountsChanged());
  }

  getStateFromStores() {
    return {accounts: AccountStore.accounts()}
  }

  _onAccountsChanged() {
    this.setState(this.getStateFromStores())
  }

  _reconnect(account) {
    const ipc = require('electron').ipcRenderer;
    ipc.send('command', 'application:add-account', account.provider);
  }

  _openPreferences() {
    Actions.switchPreferencesTab('Accounts');
    Actions.openPreferences()
  }

  _contactSupport() {
    const {shell} = require("electron");
    shell.openExternal("https://support.nylas.com/hc/en-us/requests/new");
  }

  renderErrorHeader(message, buttonName, actionCallback) {
    return (
      <div className="account-error-header notifications-sticky">
        <div className={"notifications-sticky-item notification-error has-default-action"}
             onClick={actionCallback}>
         <RetinaImg
           className="icon"
           name="icon-alert-onred.png"
           mode={RetinaImg.Mode.ContentPreserve} />
          <div className="message">
            {message}
          </div>
          <a className="action default" onClick={actionCallback}>
            {buttonName}
          </a>
        </div>
      </div>)
  }

  render() {
    const errorAccounts = this.state.accounts.filter(a => a.hasSyncStateError());
    if (errorAccounts.length === 1) {
      const account = errorAccounts[0];

      switch (account.syncState) {

      case Account.SYNC_STATE_AUTH_FAILED:
        return this.renderErrorHeader(
          `Nylas N1 can no longer authenticate with ${account.emailAddress}. Click here to reconnect.`,
          "Reconnect",
          ()=>this._reconnect(account));

      case Account.SYNC_STATE_STOPPED:
        return this.renderErrorHeader(
          `The cloud sync for ${account.emailAddress} has been disabled. You will
          not be able to send or receive mail. Please contact Nylas support.`,
          "Contact support",
          ()=>this._contactSupport());

      default:
        return this.renderErrorHeader(
          `Nylas encountered an error while syncing mail for ${account.emailAddress} - we're
          looking into it. Contact Nylas support for details.`,
          "Contact support",
          ()=>this._contactSupport());
      }
    }
    if (errorAccounts.length > 1) {
      return this.renderErrorHeader("Several of your accounts are having issues. " +
        "You will not be able to send or receive mail. Click here to manage your accounts.",
        "Open preferences",
        ()=>this._openPreferences());
    }
    return false;
  }
}

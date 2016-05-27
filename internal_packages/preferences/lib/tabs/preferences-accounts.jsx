import _ from 'underscore';
import React from 'react';
import {ipcRenderer} from 'electron';
import {AccountStore, Actions} from 'nylas-exports';
import PreferencesAccountList from './preferences-account-list';
import PreferencesAccountDetails from './preferences-account-details';


class PreferencesAccounts extends React.Component {
  static displayName = 'PreferencesAccounts';

  constructor() {
    super();
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unsubscribe = AccountStore.listen(this._onAccountsChanged)
  }

  componentWillUnmount() {
    this.unsubscribe();
  }

  getStateFromStores({selected} = {}) {
    const accounts = AccountStore.accounts()
    return {
      accounts,
      selected: selected ? _.findWhere(accounts, {id: selected.id}) : accounts[0],
    };
  }

  _onAccountsChanged = () => {
    this.setState(this.getStateFromStores(this.state));
  }

  // Update account list actions
  _onAddAccount() {
    ipcRenderer.send('command', 'application:add-account');
  }

  _onReorderAccount(account, oldIdx, newIdx) {
    Actions.reorderAccount(account.id, newIdx);
  }

  _onSelectAccount = (account) => {
    this.setState({selected: account});
  }

  _onRemoveAccount(account) {
    Actions.removeAccount(account.id);
  }

  // Update account actions
  _onAccountUpdated(account, updates) {
    Actions.updateAccount(account.id, updates);
  }

  render() {
    return (
      <div className="container-accounts">
        <div className="accounts-content">
          <PreferencesAccountList
            accounts={this.state.accounts}
            selected={this.state.selected}
            onAddAccount={this._onAddAccount}
            onReorderAccount={this._onReorderAccount}
            onSelectAccount={this._onSelectAccount}
            onRemoveAccount={this._onRemoveAccount}
          />
          <PreferencesAccountDetails
            account={this.state.selected}
            onAccountUpdated={this._onAccountUpdated}
          />
        </div>
      </div>
    );
  }

}

export default PreferencesAccounts;

/* eslint global-require: 0 */
import React, {Component, PropTypes} from 'react';
import {EditableList} from 'nylas-component-kit';
import {RegExpUtils, Account} from 'nylas-exports';

class PreferencesAccountDetails extends Component {

  static propTypes = {
    account: PropTypes.object,
    onAccountUpdated: PropTypes.func.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = {account: props.account.clone()};
  }

  componentWillReceiveProps(nextProps) {
    this.setState({account: nextProps.account.clone()});
  }

  componentWillUnmount() {
    this._saveChanges();
  }


  // Helpers

  /**
   * @private Will transform any user input into alias format.
   * It will ignore any text after an email, if one is entered.
   * If no email is entered, it will use the account's email.
   * It will treat the text before the email as the name for the alias.
   * If no name is entered, it will use the account's name value.
   * @param {string} str - The string the user entered on the alias input
   * @param {object} [account=this.props.account] - The account object
   */
  _makeAlias(str, account = this.props.account) {
    const emailRegex = RegExpUtils.emailRegex();
    const match = emailRegex.exec(str);
    if (!match) {
      return `${str || account.name} <${account.emailAddress}>`;
    }
    const email = match[0];
    let name = str.slice(0, Math.max(0, match.index - 1));
    if (!name) {
      name = account.name || 'No name provided';
    }
    name = name.trim();
    // TODO Sanitize the name string
    return `${name} <${email}>`;
  }

  _saveChanges = () => {
    this.props.onAccountUpdated(this.props.account, this.state.account);
  };

  _setState = (updates, callback = () => {}) => {
    const account = Object.assign(this.state.account.clone(), updates);
    this.setState({account}, callback);
  };

  _setStateAndSave = (updates) => {
    this._setState(updates, () => {
      this._saveChanges();
    });
  };


  // Handlers

  _onAccountLabelUpdated = (event) => {
    this._setState({label: event.target.value});
  };

  _onAccountAliasCreated = (newAlias) => {
    const coercedAlias = this._makeAlias(newAlias);
    const aliases = this.state.account.aliases.concat([coercedAlias]);
    this._setStateAndSave({aliases})
  };

  _onAccountAliasUpdated = (newAlias, alias, idx) => {
    const coercedAlias = this._makeAlias(newAlias);
    const aliases = this.state.account.aliases.slice();
    let defaultAlias = this.state.account.defaultAlias;
    if (defaultAlias === alias) {
      defaultAlias = coercedAlias;
    }
    aliases[idx] = coercedAlias;
    this._setStateAndSave({aliases, defaultAlias});
  };

  _onAccountAliasRemoved = (alias, idx) => {
    const aliases = this.state.account.aliases.slice();
    let defaultAlias = this.state.account.defaultAlias;
    if (defaultAlias === alias) {
      defaultAlias = null;
    }
    aliases.splice(idx, 1);
    this._setStateAndSave({aliases, defaultAlias});
  };

  _onDefaultAliasSelected = (event) => {
    const defaultAlias = event.target.value === 'None' ? null : event.target.value;
    this._setStateAndSave({defaultAlias});
  };

  _onReconnect = () => {
    const ipc = require('electron').ipcRenderer;
    ipc.send('command', 'application:add-account', {existingAccount: this.state.account, source: 'Reconnect from preferences'});
  }

  _onContactSupport = () => {
    const {shell} = require("electron");
    shell.openExternal("https://support.nylas.com/hc/en-us/requests/new");
  }

  // Renderers

  _renderDefaultAliasSelector(account) {
    const aliases = account.aliases;
    const defaultAlias = account.defaultAlias || 'None';
    if (aliases.length > 0) {
      return (
        <div className="default-alias-selector">
          <div>Default for new messages:</div>
          <select value={defaultAlias} onChange={this._onDefaultAliasSelected}>
            <option value="None">{`${account.name} <${account.emailAddress}>`}</option>
            {aliases.map((alias, idx) => <option key={`alias-${idx}`} value={alias}>{alias}</option>)}
          </select>
        </div>
      );
    }
    return null;
  }


  _renderErrorDetail(message, buttonText, buttonAction) {
    return (<div className="account-error-detail">
      <div className="message">{message}</div>
      <a className="action" onClick={buttonAction}>{buttonText}</a>
    </div>)
  }

  _renderSyncErrorDetails() {
    const {account} = this.state;
    if (account.hasSyncStateError()) {
      switch (account.syncState) {
        case Account.N1_Cloud_AUTH_FAILED:
          return this._renderErrorDetail(
            `Nylas Mail can no longer authenticate N1 Cloud Services with
            ${account.emailAddress}. The password or authentication may
            have changed.`,
            "Reconnect",
            this._onReconnect);
        case Account.SYNC_STATE_AUTH_FAILED:
          return this._renderErrorDetail(
            `Nylas Mail can no longer authenticate with ${account.emailAddress}. The password or
            authentication may have changed.`,
            "Reconnect",
            this._onReconnect);
        default:
          return this._renderErrorDetail(
            `Nylas encountered an error while syncing mail for ${account.emailAddress}. Contact Nylas support for details.`,
            "Contact support",
            this._onContactSupport);
      }
    }
    return null;
  }

  render() {
    const {account} = this.state;
    const aliasPlaceholder = this._makeAlias(
      `alias@${account.emailAddress.split('@')[1]}`
    );

    return (
      <div className="account-details">
        {this._renderSyncErrorDetails()}
        <h3>Account Label</h3>
        <input
          type="text"
          value={account.label}
          onBlur={this._saveChanges}
          onChange={this._onAccountLabelUpdated}
        />

        <h3>Account Settings</h3>

        <div className="btn" onClick={this._onReconnect}>
          {account.provider === 'imap' ? 'Update Connection Settings...' : 'Re-authenticate...'}
        </div>

        <h3>Aliases</h3>

        <div className="platform-note">
          You may need to configure aliases with your
          mail provider (Outlook, Gmail) before using them.
        </div>

        <EditableList
          showEditIcon
          items={account.aliases}
          createInputProps={{placeholder: aliasPlaceholder}}
          onItemCreated={this._onAccountAliasCreated}
          onItemEdited={this._onAccountAliasUpdated}
          onDeleteItem={this._onAccountAliasRemoved}
        />

        {this._renderDefaultAliasSelector(account)}
      </div>
    );
  }

}

export default PreferencesAccountDetails;

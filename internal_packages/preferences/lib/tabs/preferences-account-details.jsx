import _ from 'underscore';
import React, {Component, PropTypes} from 'react';
import {EditableList, NewsletterSignup} from 'nylas-component-kit';
import {RegExpUtils} from 'nylas-exports';

class PreferencesAccountDetails extends Component {

  static propTypes = {
    account: PropTypes.object,
    onAccountUpdated: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);
    this.state = _.clone(props.account);
  }

  componentWillReceiveProps(nextProps) {
    this.setState(_.clone(nextProps.account));
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
      return `${str} <${account.emailAddress}>`;
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

  _updatedDefaultAlias(originalAlias, newAlias, defaultAlias) {
    if (originalAlias === defaultAlias) {
      return newAlias;
    }
    return defaultAlias;
  }

  _saveChanges = ()=> {
    this.props.onAccountUpdated(this.props.account, this.state);
  }


  // Handlers

  _onAccountLabelUpdated = (event)=> {
    this.setState({label: event.target.value});
  }

  _onAccountAliasCreated = (newAlias)=> {
    const coercedAlias = this._makeAlias(newAlias);
    const aliases = this.state.aliases.concat([coercedAlias]);
    this.setState({aliases}, ()=> {
      this._saveChanges();
    });
  }

  _onAccountAliasUpdated = (newAlias, alias, idx)=> {
    const coercedAlias = this._makeAlias(newAlias);
    const aliases = this.state.aliases.slice();
    let defaultAlias = this.state.defaultAlias;
    if (defaultAlias === alias) {
      defaultAlias = coercedAlias;
    }
    aliases[idx] = coercedAlias;
    this.setState({aliases, defaultAlias}, ()=> {
      this._saveChanges();
    });
  }

  _onAccountAliasRemoved = (alias, idx)=> {
    const aliases = this.state.aliases.slice();
    let defaultAlias = this.state.defaultAlias;
    if (defaultAlias === alias) {
      defaultAlias = null;
    }
    aliases.splice(idx, 1);
    this.setState({aliases, defaultAlias}, ()=> {
      this._saveChanges();
    });
  }

  _onDefaultAliasSelected = (event)=> {
    const defaultAlias = event.target.value === 'None' ? null : event.target.value;
    this.setState({defaultAlias}, ()=> {
      this._saveChanges();
    });
  }


  // Renderers

  _renderDefaultAliasSelector(account) {
    const aliases = account.aliases;
    const defaultAlias = account.defaultAlias || 'None';
    if (aliases.length > 0) {
      return (
        <div className="default-alias-selector">
          <span>Default alias: </span>
          <select value={defaultAlias} onChange={this._onDefaultAliasSelected}>
            <option>None</option>
            {aliases.map((alias, idx)=> <option key={`alias-${idx}`} value={alias}>{alias}</option>)}
          </select>
        </div>
      );
    }
  }

  render() {
    const account = this.state;
    const aliasPlaceholder = this._makeAlias(
      `alias@${account.emailAddress.split('@')[1]}`
    );

    return (
      <div className="account-details">
        <h3>Account Label</h3>
        <input
          type="text"
          value={account.label}
          onBlur={this._saveChanges}
          onChange={this._onAccountLabelUpdated} />

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
          onDeleteItem={this._onAccountAliasRemoved} />

        {this._renderDefaultAliasSelector(account)}

        <div className="newsletter">
          <NewsletterSignup emailAddress={account.emailAddress} name={account.name} />
        </div>
      </div>
    );
  }

}

export default PreferencesAccountDetails;

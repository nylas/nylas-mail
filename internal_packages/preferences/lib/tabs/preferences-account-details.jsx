import _ from 'underscore';
import React, {Component, PropTypes} from 'react';
import {EditableList} from 'nylas-component-kit';
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
    // TODO Sanitize the name string
    return `${name} <${email}>`;
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

    aliases[idx] = coercedAlias;
    this.setState({aliases}, ()=> {
      this._saveChanges();
    });
  }

  _onAccountAliasRemoved = (alias, idx)=> {
    const aliases = this.state.aliases.slice();
    aliases.splice(idx, 1);
    this.setState({aliases}, ()=> {
      this._saveChanges();
    });
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
        <EditableList
          showEditIcon
          createInputProps={{placeholder: aliasPlaceholder}}
          onItemCreated={this._onAccountAliasCreated}
          onItemEdited={this._onAccountAliasUpdated}
          onDeleteItem={this._onAccountAliasRemoved} >
          {account.aliases}
        </EditableList>
      </div>
    );
  }

}

export default PreferencesAccountDetails;

import React from 'react';
import classnames from 'classnames';

import {AccountStore} from 'nylas-exports';
import {Menu, ButtonDropdown} from 'nylas-component-kit';

export default class AccountContactField extends React.Component {
  static displayName = 'AccountContactField';

  static propTypes = {
    value: React.PropTypes.object,
    accounts: React.PropTypes.array.isRequired,
    onChange: React.PropTypes.func.isRequired,
  };

  _onChooseContact = (contact) => {
    this.props.onChange({from: [contact]});
    this.refs.dropdown.toggleDropdown();
  }

  _renderAccountSelector() {
    if (!this.props.value) {
      return (
        <span/>
      );
    }

    const label = this.props.value.toString();
    const multipleAccounts = this.props.accounts.length > 1;
    const hasAliases = this.props.accounts[0] && this.props.accounts[0].aliases.length > 0;

    if (multipleAccounts || hasAliases) {
      return (
        <ButtonDropdown
          ref="dropdown"
          bordered={false}
          primaryItem={<span>{label}</span>}
          menu={this._renderAccounts(this.props.accounts)}
        />
      );
    }
    return this._renderAccountSpan(label);
  }

  _renderAccountSpan = (label) => {
    return (
      <span style={{position: "relative", top: 13, left: "0.5em"}}>
        {label}
      </span>
    );
  }

  _renderMenuItem = (contact) => {
    const className = classnames({
      'contact': true,
      'is-alias': contact.isAlias,
    });
    return (
      <span className={className}>{contact.toString()}</span>
    );
  }

  _renderAccounts(accounts) {
    const items = AccountStore.aliasesFor(accounts);
    return (
      <Menu
        items={items}
        itemKey={contact => contact.id}
        itemContent={this._renderMenuItem}
        onSelect={this._onChooseContact}
      />
    );
  }

  render() {
    return (
      <div className="composer-participant-field">
        <div className="composer-field-label">From:</div>
        {this._renderAccountSelector()}
      </div>
    );
  }
}

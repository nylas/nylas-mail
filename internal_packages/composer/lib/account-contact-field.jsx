import React from 'react';
import classnames from 'classnames';
import {
  AccountStore,
} from 'nylas-exports';
import {Menu, ButtonDropdown, InjectedComponentSet} from 'nylas-component-kit';

export default class AccountContactField extends React.Component {
  static displayName = 'AccountContactField';

  static propTypes = {
    value: React.PropTypes.object,
    accounts: React.PropTypes.array,
    session: React.PropTypes.object.isRequired,
    draft: React.PropTypes.object.isRequired,
    onChange: React.PropTypes.func.isRequired,
  };

  _onChooseContact = (contact) => {
    this.props.onChange({from: [contact]});
    this.props.session.ensureCorrectAccount()
    this.refs.dropdown.toggleDropdown();
  }

  _renderAccountSelector() {
    if (!this.props.value) {
      return (
        <span />
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
      <span className="from-single-name" style={{position: "relative", top: 13, left: "0.5em"}}>
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


  _renderFromFieldComponents = () => {
    const {draft, session, accounts} = this.props
    return (
      <InjectedComponentSet
        className="dropdown-component"
        matching={{role: "Composer:FromFieldComponents"}}
        exposedProps={{
          draft,
          session,
          accounts,
          currentAccount: draft.from[0],
        }}
      />
    )
  }

  render() {
    return (
      <div className="composer-participant-field from-field">
        <div className="composer-field-label">From:</div>
        {this._renderAccountSelector()}
        {this._renderFromFieldComponents()}
      </div>
    );
  }
}

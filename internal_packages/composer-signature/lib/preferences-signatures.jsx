import React from 'react';
import {Contenteditable} from 'nylas-component-kit';
import {AccountStore} from 'nylas-exports';
import SignatureStore from './signature-store';
import SignatureActions from './signature-actions';

export default class PreferencesSignatures extends React.Component {
  static displayName = 'PreferencesSignatures';

  constructor(props) {
    super(props);
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this.usub = AccountStore.listen(this._onChange);
  }

  componentWillUnmount() {
    this.usub();
  }

  _onChange = () => {
    this.setState(this._getStateFromStores());
  }

  _getStateFromStores() {
    const accounts = AccountStore.accounts();
    const state = this.state || {};

    let {currentAccountId} = state;
    if (!accounts.find(acct => acct.id === currentAccountId)) {
      currentAccountId = accounts[0].id;
    }
    return {
      accounts,
      currentAccountId,
      currentSignature: SignatureStore.signatureForAccountId(currentAccountId),
      editAsHTML: state.editAsHTML,
    };
  }

  _renderAccountPicker() {
    const options = this.state.accounts.map(account =>
      <option value={account.id} key={account.id}>{account.emailAddress}</option>
    );

    return (
      <select value={this.state.currentAccountId} onChange={this._onSelectAccount}>
        {options}
      </select>
    );
  }

  _renderEditableSignature() {
    return (
      <Contenteditable
        tabIndex={-1}
        ref="signatureInput"
        value={this.state.currentSignature}
        onChange={this._onEditSignature}
        spellcheck={false}
      />
     );
  }

  _renderHTMLSignature() {
    return (
      <textarea
        ref="signatureHTMLInput"
        value={this.state.currentSignature}
        onChange={this._onEditSignature}
      />
    );
  }

  _onEditSignature = (event) => {
    const html = event.target.value;
    this.setState({currentSignature: html});

    SignatureActions.setSignatureForAccountId({
      accountId: this.state.currentAccountId,
      signature: html,
    });
  }

  _onSelectAccount = (event) => {
    const accountId = event.target.value;
    this.setState({
      currentSignature: SignatureStore.signatureForAccountId(accountId),
      currentAccountId: accountId,
    });
  }

  _renderModeToggle() {
    const label = this.state.editAsHTML ? "Edit live preview" : "Edit raw HTML";
    const action = () => {
      this.setState({editAsHTML: !this.state.editAsHTML});
      return;
    };

    return (
      <a onClick={action}>{label}</a>
    );
  }

  render() {
    const rawText = this.state.editAsHTML ? "Raw HTML " : "";
    return (
      <section className="container-signatures">
        <h2>Signatures</h2>
        <div className="section-title">
          {rawText}Signature for: {this._renderAccountPicker()}
        </div>
        <div className="signature-wrap">
          {this.state.editAsHTML ? this._renderHTMLSignature() : this._renderEditableSignature()}
        </div>
        <div className="toggle-mode" style={{marginTop: "1em"}}>{this._renderModeToggle()}</div>
      </section>
    )
  }
}

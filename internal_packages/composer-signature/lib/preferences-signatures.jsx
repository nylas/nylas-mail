import React from 'react';
import _ from 'underscore';
import {
    Flexbox,
    RetinaImg,
    EditableList,
    Contenteditable,
    MultiselectDropdown,
} from 'nylas-component-kit';
import {AccountStore, SignatureStore, Actions} from 'nylas-exports';


export default class PreferencesSignatures extends React.Component {
  static displayName = 'PreferencesSignatures';

  constructor() {
    super()
    this.state = this._getStateFromStores()
  }

  componentDidMount() {
    this.unsubscribers = [
      SignatureStore.listen(this._onChange),
    ]
  }

  componentWillUnmount() {
    this.unsubscribers.forEach(unsubscribe => unsubscribe());
  }


  _onChange = () => {
    this.setState(this._getStateFromStores())
  }

  _getStateFromStores() {
    const signatures = SignatureStore.getSignatures()
    const accountsAndAliases = AccountStore.aliases()
    const selected = SignatureStore.selectedSignature()
    const defaults = SignatureStore.getDefaults()
    return {
      signatures: signatures,
      selectedSignature: selected,
      defaults: defaults,
      accountsAndAliases: accountsAndAliases,
      editAsHTML: this.state ? this.state.editAsHTML : false,
    }
  }


  _onCreateButtonClick = () => {
    this._onAddSignature()
  }

  _onAddSignature = () => {
    Actions.addSignature()
  }

  _onDeleteSignature = (signature) => {
    Actions.removeSignature(signature)
  }

  _onEditSignature = (edit) => {
    let editedSig;
    if (typeof edit === "object") {
      editedSig = {
        title: this.state.selectedSignature.title,
        body: edit.target.value,
      }
    } else {
      editedSig = {
        title: edit,
        body: this.state.selectedSignature.body,
      }
    }
    Actions.updateSignature(editedSig, this.state.selectedSignature.id)
  }

  _onSelectSignature = (sig) => {
    Actions.selectSignature(sig.id)
  }

  _onToggleAccount = (account) => {
    Actions.toggleAccount(account.email)
  }

  _onToggleEditAsHTML = () => {
    const toggled = !this.state.editAsHTML
    this.setState({editAsHTML: toggled})
  }

  _renderListItemContent = (sig) => {
    return sig.title
  }

  _renderSignatureToolbar() {
    return (
      <div className="editable-toolbar">
        <div className="account-picker">
          Default for: {this._renderAccountPicker()}
        </div>
        <div className="render-mode">
          <input type="checkbox" id="render-mode" checked={this.state.editAsHTML} onClick={this._onToggleEditAsHTML} />
          <label>Edit raw HTML</label>
        </div>
      </div>
    )
  }

  _selectItemKey = (accountOrAlias) => {
    return accountOrAlias.clientId
  }

  _isChecked = (accountOrAlias) => {
    if (this.state.defaults[accountOrAlias.email] === this.state.selectedSignature.id) return true
    return false
  }

  _numSelected() {
    const sel = _.filter(this.state.accountsAndAliases, (accountOrAlias) => {
      return this._isChecked(accountOrAlias)
    })
    const numSelected = sel.length
    return numSelected.toString() + (numSelected === 1 ? " Account" : " Accounts")
  }

  _getEmail = (accountOrAlias) => {
    return accountOrAlias.email
  }

  _renderAccountPicker() {
    const buttonText = this._numSelected()

    return (
      <MultiselectDropdown
        className="account-dropdown"
        items={this.state.accountsAndAliases}
        itemChecked={this._isChecked}
        onToggleItem={this._onToggleAccount}
        itemKey={this._selectItemKey}
        current={this.selectedSignature}
        buttonText={buttonText}
        itemContent={this._getEmail}
      />
    )
  }

  _renderEditableSignature() {
    const selectedBody = this.state.selectedSignature ? this.state.selectedSignature.body : ""
    return (
      <Contenteditable
        ref="signatureInput"
        value={selectedBody}
        spellcheck={false}
        onChange={this._onEditSignature}
      />
    )
  }

  _renderHTMLSignature() {
    return (
      <textarea
        value={this.state.selectedSignature.body}
        onChange={this._onEditSignature}
      />
    );
  }

  _renderSignatures() {
    const sigArr = _.values(this.state.signatures)
    if (sigArr.length === 0) {
      return (
        <div className="empty-list">
          <RetinaImg
            className="icon-signature"
            name="signatures-big.png"
            mode={RetinaImg.Mode.ContentDark}
          />
          <h2>No signatures</h2>
          <button className="btn btn-small btn-create-signature" onMouseDown={this._onCreateButtonClick}>
              Create a new signature
          </button>
        </div>
      );
    }
    return (
      <Flexbox>
        <EditableList
          showEditIcon
          className="signature-list"
          items={sigArr}
          itemContent={this._renderListItemContent}
          onCreateItem={this._onAddSignature}
          onDeleteItem={this._onDeleteSignature}
          onItemEdited={this._onEditSignature}
          onSelectItem={this._onSelectSignature}
          selected={this.state.selectedSignature}
        />
        <div className="signature-wrap">
            {this.state.editAsHTML ? this._renderHTMLSignature() : this._renderEditableSignature()}
            {this._renderSignatureToolbar()}
        </div>
      </Flexbox>
    )
  }

  render() {
    return (
      <div className="preferences-signatures-container">
        <section>
          {this._renderSignatures()}
        </section>
      </div>
    )
  }
}

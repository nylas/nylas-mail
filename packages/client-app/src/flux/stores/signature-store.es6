import {Utils, Actions, AccountStore} from 'nylas-exports';
import NylasStore from 'nylas-store'
import _ from 'underscore'

const DefaultSignatureText = "Sent from <a href=\"https://nylas.com?ref=n1\">Nylas Mail</a>, the best free email app for work";

class SignatureStore extends NylasStore {

  activate() {
    this.unsubscribers = [
      Actions.addSignature.listen(this._onAddSignature),
      Actions.removeSignature.listen(this._onRemoveSignature),
      Actions.updateSignature.listen(this._onEditSignature),
      Actions.selectSignature.listen(this._onSelectSignature),
      Actions.toggleAccount.listen(this._onToggleAccount),
    ];

    NylasEnv.config.onDidChange(`nylas.signatures`, () => {
      this.signatures = NylasEnv.config.get(`nylas.signatures`)
      this.trigger()
    });
    NylasEnv.config.onDidChange(`nylas.defaultSignatures`, () => {
      this.defaultSignatures = NylasEnv.config.get(`nylas.defaultSignatures`)
      this.trigger()
    });
    this.signatures = NylasEnv.config.get(`nylas.signatures`) || {}
    this.defaultSignatures = NylasEnv.config.get(`nylas.defaultSignatures`) || {}

    // backfill the new signatures structure with old signatures from < v0.4.45
    let changed = false;
    for (const account of AccountStore.accounts()) {
      const signature = NylasEnv.config.get(`nylas.account-${account.id}.signature`)
      if (signature) {
        const newId = Utils.generateTempId();
        this.signatures[newId] = {id: newId, title: account.label, body: signature};
        this.defaultSignatures[account.emailAddress] = newId;
        NylasEnv.config.unset(`nylas.account-${account.id}.signature`);
        changed = true;
      }
    }
    if (changed) {
      this._saveSignatures();
      this._saveDefaultSignatures();
    }

    this.selectedSignatureId = this._setSelectedSignatureId()

    this.trigger()
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub());
  }

  getSignatures() {
    return this.signatures;
  }

  selectedSignature() {
    return this.signatures[this.selectedSignatureId]
  }

  getDefaults() {
    return this.defaultSignatures
  }

  signatureForEmail = (email) => {
    return this.signatures[this.defaultSignatures[email]] || {id: 'default', body: DefaultSignatureText, title: 'Default'}
  }

  _saveSignatures() {
    _.debounce(NylasEnv.config.set(`nylas.signatures`, this.signatures), 500)
  }

  _saveDefaultSignatures() {
    _.debounce(NylasEnv.config.set(`nylas.defaultSignatures`, this.defaultSignatures), 500)
  }


  _onSelectSignature = (id) => {
    this.selectedSignatureId = id
    this.trigger()
  }

  _removeByKey = (obj, keyToDelete) => {
    return Object.keys(obj)
      .filter(key => key !== keyToDelete)
      .reduce((result, current) => {
        result[current] = obj[current];
        return result;
      }, {})
  }

  _setSelectedSignatureId() {
    const sigIds = Object.keys(this.signatures)
    if (sigIds.length) {
      return sigIds[0]
    }
    return null
  }

  _onRemoveSignature = (signatureToDelete) => {
    this.signatures = this._removeByKey(this.signatures, signatureToDelete.id)
    this.selectedSignatureId = this._setSelectedSignatureId()
    this.trigger()
    this._saveSignatures()
  }

  _onAddSignature = (sigTitle = "Untitled") => {
    const newId = Utils.generateTempId()
    this.signatures[newId] = {id: newId, title: sigTitle, body: DefaultSignatureText}
    this.selectedSignatureId = newId
    this.trigger()
    this._saveSignatures()
  }

  _onEditSignature = (editedSig, oldSigId) => {
    this.signatures[oldSigId].title = editedSig.title
    this.signatures[oldSigId].body = editedSig.body
    this.trigger()
    this._saveSignatures()
  }

  _onToggleAccount = (email) => {
    if (this.defaultSignatures[email] === this.selectedSignatureId) {
      this.defaultSignatures[email] = null
    } else {
      this.defaultSignatures[email] = this.selectedSignatureId
    }

    this.trigger()
    this._saveDefaultSignatures()
  }

}

export default new SignatureStore();

import {Utils, Actions} from 'nylas-exports';
import NylasStore from 'nylas-store'
import _ from 'underscore'

const DefaultSignature = "Sent from <a href=\"https://nylas.com/n1?ref=n1\">Nylas N1</a>, the extensible, open source mail client.";

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
    })
    NylasEnv.config.onDidChange(`nylas.defaultSignatures`, () => {
      this.defaultSignatures = NylasEnv.config.get(`nylas.defaultSignatures`)
      this.trigger()
    })
    this.signatures = NylasEnv.config.get(`nylas.signatures`) || {}
    this.selectedSignatureId = this._setSelectedSignatureId()
    this.defaultSignatures = NylasEnv.config.get(`nylas.defaultSignatures`) || {}
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

  signatureForAccountId = (accountId) => {
    return this.signatures[this.defaultSignatures[accountId]]
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
    this.signatures[newId] = {id: newId, title: sigTitle, body: DefaultSignature}
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

  _onToggleAccount = (accountId) => {
    if (this.defaultSignatures[accountId] === this.selectedSignatureId) {
      this.defaultSignatures[accountId] = null
    } else {
      this.defaultSignatures[accountId] = this.selectedSignatureId
    }

    this.trigger()
    this._saveDefaultSignatures()
  }

}

export default new SignatureStore();

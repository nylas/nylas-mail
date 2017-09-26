import { Utils, Actions } from 'mailspring-exports';
import MailspringStore from 'mailspring-store';
import _ from 'underscore';

const DefaultSignatureText =
  'Sent from <a href="https://getmailspring.com?ref=client">Mailspring</a>, the best free email app for work';

class SignatureStore extends MailspringStore {
  constructor() {
    super();
    this.activate(); // for specs
  }

  activate() {
    this.signatures = AppEnv.config.get(`nylas.signatures`) || {};
    this.defaultSignatures = AppEnv.config.get(`nylas.defaultSignatures`) || {};
    this._autoselectSignatureId();

    if (!this.unsubscribers) {
      this.unsubscribers = [
        Actions.addSignature.listen(this._onAddSignature),
        Actions.removeSignature.listen(this._onRemoveSignature),
        Actions.updateSignature.listen(this._onEditSignature),
        Actions.selectSignature.listen(this._onSelectSignature),
        Actions.toggleAccount.listen(this._onToggleAccount),
      ];

      AppEnv.config.onDidChange(`nylas.signatures`, () => {
        this.signatures = AppEnv.config.get(`nylas.signatures`);
        this.trigger();
      });
      AppEnv.config.onDidChange(`nylas.defaultSignatures`, () => {
        this.defaultSignatures = AppEnv.config.get(`nylas.defaultSignatures`);
        this.trigger();
      });
    }
  }

  deactivate() {
    throw new Error("Unimplemented - core stores shouldn't be deactivated.");
  }

  getSignatures() {
    return this.signatures;
  }

  selectedSignature() {
    return this.signatures[this.selectedSignatureId];
  }

  getDefaults() {
    return this.defaultSignatures;
  }

  signatureForEmail = email => {
    return (
      this.signatures[this.defaultSignatures[email]] || {
        id: 'default',
        body: DefaultSignatureText,
        title: 'Default',
      }
    );
  };

  _saveSignatures() {
    _.debounce(AppEnv.config.set(`nylas.signatures`, this.signatures), 500);
  }

  _saveDefaultSignatures() {
    _.debounce(AppEnv.config.set(`nylas.defaultSignatures`, this.defaultSignatures), 500);
  }

  _onSelectSignature = id => {
    this.selectedSignatureId = id;
    this.trigger();
  };

  _autoselectSignatureId() {
    const sigIds = Object.keys(this.signatures);
    this.selectedSignatureId = sigIds.length ? sigIds[0] : null;
  }

  _onRemoveSignature = signatureToDelete => {
    this.signatures = Object.assign({}, this.signatures);
    delete this.signatures[signatureToDelete.id];
    this._autoselectSignatureId();
    this.trigger();
    this._saveSignatures();
  };

  _onAddSignature = (sigTitle = 'Untitled') => {
    const newId = Utils.generateTempId();
    this.signatures[newId] = { id: newId, title: sigTitle, body: DefaultSignatureText };
    this.selectedSignatureId = newId;
    this.trigger();
    this._saveSignatures();
  };

  _onEditSignature = (editedSig, oldSigId) => {
    this.signatures[oldSigId].title = editedSig.title;
    this.signatures[oldSigId].body = editedSig.body;
    this.trigger();
    this._saveSignatures();
  };

  _onToggleAccount = email => {
    if (this.defaultSignatures[email] === this.selectedSignatureId) {
      this.defaultSignatures[email] = null;
    } else {
      this.defaultSignatures[email] = this.selectedSignatureId;
    }

    this.trigger();
    this._saveDefaultSignatures();
  };
}

export default new SignatureStore();

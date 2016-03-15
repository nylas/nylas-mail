import {DraftStore, AccountStore, Actions} from 'nylas-exports';
import SignatureUtils from './signature-utils';
import SignatureActions from './signature-actions';


class SignatureStore {

  DefaultSignature = "Sent from <a href=\"https://nylas.com/n1?ref=n1\">Nylas N1</a>, the extensible, open source mail client.";

  constructor() {
    this.unsubscribes = [];
  }

  activate() {
    this.unsubscribes.push(
      SignatureActions.setSignatureForAccountId.listen(this._onSetSignatureForAccountId)
    );
    this.unsubscribes.push(
      Actions.draftParticipantsChanged.listen(this._onParticipantsChanged)
    );
  }

  deactivate() {
    this.unsubscribes.forEach(unsub => unsub());
  }

  signatureForAccountId(accountId) {
    if (!accountId) {
      return this.DefaultSignature;
    }
    const saved = NylasEnv.config.get(`nylas.account-${accountId}.signature`);
    if (saved === undefined) {
      return this.DefaultSignature;
    }
    return saved;
  }

  _onParticipantsChanged = (draftClientId, changes) => {
    if (!changes.from) { return; }

    DraftStore.sessionForClientId(draftClientId).then((session) => {
      const draft = session.draft();
      const {accountId} = AccountStore.accountForEmail(changes.from[0].email);
      const signature = this.signatureForAccountId(accountId);

      const body = SignatureUtils.applySignature(draft.body, signature);
      session.changes.add({body});
    });
  }

  _onSetSignatureForAccountId = ({signature, accountId}) => {
    // NylasEnv.config.set is internally debounced 100ms
    NylasEnv.config.set(`nylas.account-${accountId}.signature`, signature)
  }
}

export default new SignatureStore();

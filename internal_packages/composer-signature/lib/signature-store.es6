import {DraftStore, AccountStore, Actions} from 'nylas-exports';
import SignatureUtils from './signature-utils';

export default class SignatureStore {

  constructor() {
    this.unsubscribe = ()=> {};
  }

  activate() {
    this.unsubscribe = Actions.draftParticipantsChanged.listen(this.onParticipantsChanged);
  }

  onParticipantsChanged(draftClientId, changes) {
    if (!changes.from) { return; }
    DraftStore.sessionForClientId(draftClientId).then((session)=> {
      const draft = session.draft();
      const {accountId} = AccountStore.accountForEmail(changes.from[0].email);
      const signature = NylasEnv.config.get(`nylas.account-${accountId}.signature`) || "";

      const body = SignatureUtils.applySignature(draft.body, signature);
      session.changes.add({body});
    });
  }

  deactivate() {
    this.unsubscribe();
  }
}

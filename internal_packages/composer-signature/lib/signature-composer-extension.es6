import {ComposerExtension} from 'nylas-exports';
import SignatureUtils from './signature-utils';
import SignatureStore from './signature-store';

export default class SignatureComposerExtension extends ComposerExtension {
  static prepareNewDraft = ({draft}) => {
    const accountId = draft.accountId;
    const signature = SignatureStore.signatureForAccountId(accountId);
    if (!signature) {
      return;
    }
    draft.body = SignatureUtils.applySignature(draft.body, signature);
  }

  static finalizeSessionBeforeSending = ({session}) => {
    // remove the <signature> element from the DOM,
    // essentially unwraps the signature
    const body = session.draft().body;
    const changed = body.replace(/<\/?signature>/g, '');
    if (body !== changed) {
      session.changes.add({body: changed})
    }
  }
}

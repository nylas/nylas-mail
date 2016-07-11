import {ComposerExtension, SignatureStore} from 'nylas-exports';
import SignatureUtils from './signature-utils';

export default class SignatureComposerExtension extends ComposerExtension {
  static prepareNewDraft = ({draft}) => {
    const accountId = draft.accountId;
    const signatureObj = SignatureStore.signatureForAccountId(accountId);
    if (!signatureObj) {
      return;
    }
    draft.body = SignatureUtils.applySignature(draft.body, signatureObj.body);
  }
}

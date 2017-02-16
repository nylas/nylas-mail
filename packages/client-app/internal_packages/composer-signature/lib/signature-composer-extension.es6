import {ComposerExtension, SignatureStore} from 'nylas-exports';
import SignatureUtils from './signature-utils';

export default class SignatureComposerExtension extends ComposerExtension {
  static prepareNewDraft = ({draft}) => {
    const signatureObj = draft.from && draft.from[0] ? SignatureStore.signatureForEmail(draft.from[0].email) : null;
    if (!signatureObj) {
      return;
    }
    draft.body = SignatureUtils.applySignature(draft.body, signatureObj.body);
  }
}

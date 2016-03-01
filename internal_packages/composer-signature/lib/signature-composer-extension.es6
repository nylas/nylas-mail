import {ComposerExtension} from 'nylas-exports';
import SignatureUtils from './signature-utils';

export default class SignatureComposerExtension extends ComposerExtension {
  static prepareNewDraft = ({draft})=> {
    const accountId = draft.accountId;
    const signature = NylasEnv.config.get(`nylas.account-${accountId}.signature`);
    if (!signature) {
      return;
    }
    draft.body = SignatureUtils.applySignature(draft.body, signature);
  }
}

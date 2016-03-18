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

  static applyTransformsToDraft = ({draft}) => {
    const nextDraft = draft.clone();
    nextDraft.body = nextDraft.body.replace(/<\/?signature[^>]*>/g, (match) =>
      `<!-- ${match} -->`
    );
    return nextDraft;
  }

  static unapplyTransformsToDraft = ({draft}) => {
    const nextDraft = draft.clone();
    nextDraft.body = nextDraft.body.replace(/<!-- (<\/?signature[^>]*>) -->/g, (match, node) =>
      node
    );
    return nextDraft;
  }
}

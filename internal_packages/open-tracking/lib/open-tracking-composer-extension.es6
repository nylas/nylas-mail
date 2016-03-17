import {ComposerExtension, QuotedHTMLTransformer} from 'nylas-exports';
import {PLUGIN_ID, PLUGIN_URL} from './open-tracking-constants';


class DraftBody {
  constructor(draft) {this._body = draft.body}
  get unquoted() {return QuotedHTMLTransformer.removeQuotedHTML(this._body);}
  set unquoted(text) {this._body = QuotedHTMLTransformer.appendQuotedHTML(text, this._body);}
  get body() {return this._body}
}

export default class OpenTrackingComposerExtension extends ComposerExtension {

  static applyTransformsToDraft({draft}) {
    // grab message metadata, if any
    const nextDraft = draft.clone();
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (!metadata) {
      return nextDraft;
    }

    if (!metadata.uid) {
      NylasEnv.reportError(new Error("Open tracking composer extension could not find 'uid' in metadata!"));
      return nextDraft;
    }

    // insert a tracking pixel <img> into the message
    const serverUrl = `${PLUGIN_URL}/open/${draft.accountId}/${metadata.uid}`;
    const img = `<img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" src="${serverUrl}">`;
    const draftBody = new DraftBody(draft);

    draftBody.unquoted = `${draftBody.unquoted}${img}`;
    nextDraft.body = draftBody.body;
    return nextDraft;
  }

  static unapplyTransformsToDraft({draft}) {
    const nextDraft = draft.clone();
    nextDraft.body = draft.body.replace(/<img class="n1-open"[^>]*>/g, '');
    return nextDraft;
  }
}

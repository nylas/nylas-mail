import {ComposerExtension, QuotedHTMLTransformer} from 'nylas-exports';
import {PLUGIN_ID, PLUGIN_URL} from './open-tracking-constants';


class DraftBody {
  constructor(draft) {this._body = draft.body}
  get unquoted() {return QuotedHTMLTransformer.removeQuotedHTML(this._body);}
  set unquoted(text) {this._body = QuotedHTMLTransformer.appendQuotedHTML(text, this._body);}
  get body() {return this._body}
}

export default class OpenTrackingComposerExtension extends ComposerExtension {
  static finalizeSessionBeforeSending({session}) {
    const draft = session.draft();

    // grab message metadata, if any
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      // insert a tracking pixel <img> into the message
      const serverUrl = `${PLUGIN_URL}/open/${draft.accountId}/${metadata.uid}`;
      const img = `<img width="0" height="0" style="border:0; width:0; height:0;" src="${serverUrl}">`;
      const draftBody = new DraftBody(draft);
      draftBody.unquoted = draftBody.unquoted + "<br>" + img;

      // save the draft
      session.changes.add({body: draftBody.body});
    }
  }
}

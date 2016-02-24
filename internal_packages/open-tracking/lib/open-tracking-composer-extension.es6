import {ComposerExtension, Actions, QuotedHTMLTransformer} from 'nylas-exports';
import plugin from '../package.json'

import uuid from 'node-uuid';

const PLUGIN_ID = plugin.appId[NylasEnv.config.get("env")];
const PLUGIN_URL = "n1-open-tracking.herokuapp.com";

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
      // generate a UID
      const uid = uuid.v4().replace(/-/g, "");

      // insert a tracking pixel <img> into the message
      const serverUrl = `http://${PLUGIN_URL}/${draft.accountId}/${uid}`;
      const img = `<img width="0" height="0" style="border:0; width:0; height:0;" src="${serverUrl}">`;
      const draftBody = new DraftBody(draft);
      draftBody.unquoted = draftBody.unquoted + "<br>" + img;

      // save the draft
      session.changes.add({body: draftBody.body});
      session.changes.commit();

      // save the uid to draft metadata
      metadata.uid = uid;
      Actions.setMetadata(draft, PLUGIN_ID, metadata);
    }
  }
}

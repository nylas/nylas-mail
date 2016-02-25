import uuid from 'node-uuid';
import {
  ComposerExtension,
  Actions,
  QuotedHTMLTransformer,
  RegExpUtils,
} from 'nylas-exports';
import {PLUGIN_ID, PLUGIN_URL} from './link-tracking-constants'


class DraftBody {
  constructor(draft) {this._body = draft.body}
  get unquoted() {return QuotedHTMLTransformer.removeQuotedHTML(this._body);}
  set unquoted(text) {this._body = QuotedHTMLTransformer.appendQuotedHTML(text, this._body);}
  get body() {return this._body}
}

export default class LinkTrackingComposerExtension extends ComposerExtension {
  static finalizeSessionBeforeSending({session}) {
    const draft = session.draft();

    // grab message metadata, if any
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      const draftBody = new DraftBody(draft);
      const links = [];
      const messageUid = uuid.v4().replace(/-/g, "");

      // loop through all <a href> elements, replace with redirect links and save mappings
      draftBody.unquoted = draftBody.unquoted.replace(RegExpUtils.linkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
        const encoded = encodeURIComponent(url);
        // the links param is an index of the link array.
        const redirectUrl = `${PLUGIN_URL}/link/${draft.accountId}/${messageUid}/${links.length}?redirect=${encoded}`;
        links.push({url: url, click_count: 0, click_data: [], redirect_url: redirectUrl});
        return prefix + redirectUrl + suffix + content + closingTag;
      });

      // save the draft
      session.changes.add({body: draftBody.body});
      session.changes.commit();

      // save the link info to draft metadata
      metadata.uid = messageUid;
      metadata.links = links;

      Actions.setMetadata(draft, PLUGIN_ID, metadata);
    }
  }
}

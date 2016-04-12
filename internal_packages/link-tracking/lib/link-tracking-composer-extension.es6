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
  static applyTransformsToDraft({draft}) {
    // grab message metadata, if any
    const nextDraft = draft.clone();
    const metadata = nextDraft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      const draftBody = new DraftBody(draft);
      const links = [];
      const messageUid = draft.clientId;

      // loop through all <a href> elements, replace with redirect links and save
      // mappings. The links component of the path is an index of the link array.
      draftBody.unquoted = draftBody.unquoted.replace(
        RegExpUtils.urlLinkTagRegex(),
        (match, prefix, url, suffix, content, closingTag) => {
          const encoded = encodeURIComponent(url);
          const redirectUrl = `${PLUGIN_URL}/link/${draft.accountId}/${messageUid}/${links.length}?redirect=${encoded}`;
          links.push({
            url,
            click_count: 0,
            click_data: [],
            redirect_url: redirectUrl,
          });
          return prefix + redirectUrl + suffix + content + closingTag;
        }
      );

      // save the draft
      nextDraft.body = draftBody.body;

      // save the link info to draft metadata
      metadata.uid = messageUid;
      metadata.links = links;
      Actions.setMetadata(draft, PLUGIN_ID, metadata);
    }
    return nextDraft;
  }

  static unapplyTransformsToDraft({draft}) {
    const nextDraft = draft.clone();
    const draftBody = new DraftBody(draft);
    draftBody.unquoted = draftBody.unquoted.replace(
      RegExpUtils.urlLinkTagRegex(),
      (match, prefix, url, suffix, content, closingTag) => {
        if (url.indexOf(PLUGIN_URL) !== -1) {
          const userURLEncoded = url.split('?redirect=')[1];
          return prefix + decodeURIComponent(userURLEncoded) + suffix + content + closingTag;
        }
        return prefix + url + suffix + content + closingTag;
      }
    )
    nextDraft.body = draftBody.body;
    return nextDraft;
  }
}

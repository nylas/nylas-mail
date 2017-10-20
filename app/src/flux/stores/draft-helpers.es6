import { DatabaseStore } from 'mailspring-exports';
import Message from '../models/message';
import * as ExtensionRegistry from '../../registries/extension-registry';
import DOMUtils from '../../dom-utils';

import InlineStyleTransformer from '../../services/inline-style-transformer';
import SanitizeTransformer from '../../services/sanitize-transformer';
import MessageUtils from '../models/message-utils';

class DraftHelpers {
  AllowedTransformFields = ['to', 'from', 'cc', 'bcc', 'subject', 'body'];

  DraftNotFoundError = class DraftNotFoundError extends Error {};

  /**
   * Returns true if the message contains "Forwarded" or "Fwd" in the first
   * 250 characters.  A strong indicator that the quoted text should be
   * shown. Needs to be limited to first 250 to prevent replies to
   * forwarded messages from also being expanded.
  */
  isForwardedMessage({ body, subject } = {}) {
    let bodyFwd = false;
    let bodyForwarded = false;
    let subjectFwd = false;

    if (body) {
      const indexFwd = body.search(/fwd/i);
      const indexForwarded = body.search(/forwarded/i);
      bodyForwarded = indexForwarded >= 0 && indexForwarded < 250;
      bodyFwd = indexFwd >= 0 && indexFwd < 250;
    }
    if (subject) {
      subjectFwd = subject.slice(0, 3).toLowerCase() === 'fwd';
    }

    return bodyForwarded || bodyFwd || subjectFwd;
  }

  shouldAppendQuotedText({ body = '', replyToHeaderMessageId = false } = {}) {
    return (
      replyToHeaderMessageId &&
      !body.includes('<div id="mailspring-quoted-text-marker">') &&
      !body.includes(`nylas-quote-id-${replyToHeaderMessageId}`)
    );
  }

  prepareBodyForQuoting(body = '') {
    // TODO: Fix inline images
    const cidRE = MessageUtils.cidRegexString;

    // Be sure to match over multiple lines with [\s\S]*
    // Regex explanation here: https://regex101.com/r/vO6eN2/1
    body.replace(new RegExp(`<img.*${cidRE}[\\s\\S]*?>`, 'igm'), '');

    return InlineStyleTransformer.run(body).then(inlineStyled =>
      SanitizeTransformer.run(inlineStyled, SanitizeTransformer.Preset.UnsafeOnly)
    );
  }

  async pruneRemovedInlineFiles(draft) {
    draft.files = draft.files.filter(f => {
      return !(f.contentId && !draft.body.includes(`cid:${f.id}`));
    });

    return draft;
  }

  appendQuotedTextToDraft(draft) {
    const query = DatabaseStore.findBy(Message, {
      headerMessageId: draft.replyToHeaderMessageId,
      accountId: draft.accountId,
    }).include(Message.attributes.body);

    return query.then(prevMessage => {
      if (!prevMessage) {
        return Promise.resolve(draft);
      }
      return this.prepareBodyForQuoting(prevMessage.body).then(prevBodySanitized => {
        draft.body = `${draft.body}
          <div class="gmail_quote nylas-quote nylas-quote-id-${draft.replyToHeaderMessageId}">
            <br>
            ${DOMUtils.escapeHTMLCharacters(prevMessage.replyAttributionLine())}
            <br>
            <blockquote class="gmail_quote"
              style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
              ${prevBodySanitized}
            </blockquote>
          </div>`;
        return Promise.resolve(draft);
      });
    });
  }

  async applyExtensionTransforms(draft) {
    const extensions = ExtensionRegistry.Composer.extensions();

    const fragment = document.createDocumentFragment();
    const draftBodyRootNode = document.createElement('root');
    fragment.appendChild(draftBodyRootNode);
    draftBodyRootNode.innerHTML = draft.body;

    for (const ext of extensions) {
      const extApply = ext.applyTransformsForSending;
      const extUnapply = ext.unapplyTransformsForSending;

      if (!extApply || !extUnapply) {
        continue;
      }

      await extUnapply({ draft, draftBodyRootNode });
      await extApply({ draft, draftBodyRootNode });
    }

    draft.body = draftBodyRootNode.innerHTML;
    return draft;
  }
}

export default new DraftHelpers();

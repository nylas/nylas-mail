import Actions from '../actions'
import DatabaseStore from './database-store'
import Message from '../models/message'
import * as ExtensionRegistry from '../../extension-registry'
import SyncbackDraftFilesTask from '../tasks/syncback-draft-files-task'
import DOMUtils from '../../dom-utils'

import QuotedHTMLTransformer from '../../services/quoted-html-transformer'
import InlineStyleTransformer from '../../services/inline-style-transformer'
import SanitizeTransformer from '../../services/sanitize-transformer'
import MessageUtils from '../models/message-utils'


export const AllowedTransformFields = ['to', 'from', 'cc', 'bcc', 'subject', 'body']

/**
 * Returns true if the message contains "Forwarded" or "Fwd" in the first
 * 250 characters.  A strong indicator that the quoted text should be
 * shown. Needs to be limited to first 250 to prevent replies to
 * forwarded messages from also being expanded.
*/
export function isForwardedMessage({body, subject} = {}) {
  let bodyFwd = false
  let bodyForwarded = false
  let subjectFwd = false

  if (body) {
    const indexFwd = body.search(/fwd/i)
    const indexForwarded = body.search(/forwarded/i)
    bodyForwarded = indexForwarded >= 0 && indexForwarded < 250
    bodyFwd = indexFwd >= 0 && indexFwd < 250
  }
  if (subject) {
    subjectFwd = subject.slice(0, 3).toLowerCase() === "fwd"
  }

  return bodyForwarded || bodyFwd || subjectFwd
}

export function shouldAppendQuotedText({body = '', replyToMessageId = false} = {}) {
  return replyToMessageId &&
    !body.includes('<div id="n1-quoted-text-marker">') &&
    !body.includes(`nylas-quote-id-${replyToMessageId}`)
}

export function prepareBodyForQuoting(body = "") {
  // TODO: Fix inline images
  const cidRE = MessageUtils.cidRegexString;

  // Be sure to match over multiple lines with [\s\S]*
  // Regex explanation here: https://regex101.com/r/vO6eN2/1
  body.replace(new RegExp(`<img.*${cidRE}[\\s\\S]*?>`, "igm"), "")

  return InlineStyleTransformer.run(body).then((inlineStyled) =>
    SanitizeTransformer.run(inlineStyled, SanitizeTransformer.Preset.UnsafeOnly)
  )
}

export function messageMentionsAttachment({body} = {}) {
  if (body == null) { throw new Error('DraftHelpers::messageMentionsAttachment - Message has no body loaded') }
  let cleaned = QuotedHTMLTransformer.removeQuotedHTML(body.toLowerCase().trim());
  const signatureIndex = cleaned.indexOf('<signature>');
  if (signatureIndex !== -1) {
    cleaned = cleaned.substr(0, signatureIndex - 1);
  }
  return (cleaned.indexOf("attach") >= 0);
}

export function queueDraftFileUploads(draft) {
  if (draft.files.length > 0 || draft.uploads.length > 0) {
    Actions.queueTask(new SyncbackDraftFilesTask(draft.clientId))
  }
}

export function appendQuotedTextToDraft(draft) {
  const query = DatabaseStore.find(Message, draft.replyToMessageId).include(Message.attributes.body);

  return query.then((prevMessage) => {
    if (!prevMessage) {
      return Promise.resolve(draft);
    }
    return prepareBodyForQuoting(prevMessage.body).then((prevBodySanitized) => {
      draft.body = `${draft.body}
        <div class="gmail_quote nylas-quote nylas-quote-id-${draft.replyToMessageId}">
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
  })
}

export function applyExtensionTransforms(draft) {
  const extensions = ExtensionRegistry.Composer.extensions();

  const fragment = document.createDocumentFragment();
  const draftBodyRootNode = document.createElement('root');
  fragment.appendChild(draftBodyRootNode);
  draftBodyRootNode.innerHTML = draft.body;

  return Promise.each(extensions, (ext) => {
    const extApply = ext.applyTransformsForSending;
    const extUnapply = ext.unapplyTransformsForSending;

    if (!extApply || !extUnapply) {
      return Promise.resolve();
    }

    return Promise.resolve(extUnapply({draft, draftBodyRootNode})).then(() => {
      return Promise.resolve(extApply({draft, draftBodyRootNode}));
    });
  }).then(() => {
    draft.body = draftBodyRootNode.innerHTML;
    return draft;
  });
}

export function prepareDraftForSyncback(session) {
  return session.ensureCorrectAccount({noSyncback: true})
  .then(() => {
    return applyExtensionTransforms(session.draft())
  })
  .then((transformed) => {
    if (!transformed.replyToMessageId || !shouldAppendQuotedText(transformed)) {
      return Promise.resolve(transformed);
    }
    return appendQuotedTextToDraft(transformed);
  })
  .then((draft) => {
    return DatabaseStore.inTransaction((t) =>
      t.persistModel(draft)
    )
    .then(() =>
      Promise.resolve(queueDraftFileUploads(draft))
    )
    .thenReturn(draft)
  })
}

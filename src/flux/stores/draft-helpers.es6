import _ from 'underscore'
import Actions from '../actions'
import DatabaseStore from './database-store'
import Message from '../models/message'
import * as ExtensionRegistry from '../../extension-registry'
import SyncbackDraftFilesTask from '../tasks/syncback-draft-files-task'
import DOMUtils from '../../dom-utils'
import QuotedHTMLTransformer from '../../services/quoted-html-transformer'


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

export function shouldAppendQuotedText({body = ''} = {}) {
  return !body.includes('<div id="n1-quoted-text-marker">')
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
  return DatabaseStore.find(Message, draft.replyToMessageId)
  .include(Message.attributes.body)
  .then((prevMessage) => {
    const quotedText = `
      <div class="gmail_quote">
        <br>
        ${DOMUtils.escapeHTMLCharacters(prevMessage.replyAttributionLine())}
        <br>
        <blockquote class="gmail_quote"
          style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
          ${prevMessage.body}
        </blockquote>
      </div>`
    draft.body = draft.body + quotedText
    return Promise.resolve(draft)
  })
}

export function applyExtensionTransformsToDraft(draft) {
  let latestTransformed = draft
  const extensions = ExtensionRegistry.Composer.extensions()
  const transformPromise = (
    Promise.each(extensions, (ext) => {
      const extApply = ext.applyTransformsToDraft
      const extUnapply = ext.unapplyTransformsToDraft

      if (!extApply || !extUnapply) {
        return Promise.resolve()
      }

      return Promise.resolve(extUnapply({draft: latestTransformed})).then((cleaned) => {
        const base = cleaned === 'unnecessary' ? latestTransformed : cleaned;
        return Promise.resolve(extApply({draft: base})).then((transformed) => (
          Promise.resolve(extUnapply({draft: transformed.clone()})).then((reverted) => {
            const untransformed = reverted === 'unnecessary' ? base : reverted;
            if (!_.isEqual(_.pick(untransformed, AllowedTransformFields), _.pick(base, AllowedTransformFields))) {
              console.log("-- BEFORE --")
              console.log(base.body)
              console.log("-- TRANSFORMED --")
              console.log(transformed.body)
              console.log("-- UNTRANSFORMED (should match BEFORE) --")
              console.log(untransformed.body)
              NylasEnv.reportError(new Error(`Extension ${ext.name} applied a transform to the draft that it could not reverse.`))
            }
            latestTransformed = transformed
            return Promise.resolve()
          })
        ))
      })
    })
  )
  return transformPromise
  .then(() => Promise.resolve(latestTransformed))
}

export function prepareDraftForSyncback(session) {
  return session.ensureCorrectAccount({noSyncback: true})
  .then(() => applyExtensionTransformsToDraft(session.draft()))
  .then((transformed) => {
    if (!transformed.replyToMessageId || !shouldAppendQuotedText(transformed)) {
      return Promise.resolve(transformed)
    }
    return appendQuotedTextToDraft(transformed)
  })
  .then((draft) => (
    DatabaseStore.inTransaction((t) => t.persistModel(draft))
    .then(() => Promise.resolve(queueDraftFileUploads(draft)))
    .thenReturn(draft)
  ))
}

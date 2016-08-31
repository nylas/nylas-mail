marked = require 'marked'
Utils = require './utils'
{ComposerExtension} = require 'nylas-exports'


rawBodies = {}

class MarkdownComposerExtension extends ComposerExtension

  @applyTransformsToDraft: ({draft}) ->
    nextDraft = draft.clone()
    rawBodies[draft.clientId] = nextDraft.body
    nextDraft.body = marked(Utils.getTextFromHtml(draft.body))
    return nextDraft

  @unapplyTransformsToDraft: ({draft}) ->
    nextDraft = draft.clone()
    nextDraft.body = rawBodies[nextDraft.clientId] ? nextDraft.body
    return nextDraft

module.exports = MarkdownComposerExtension

marked = require 'marked'
Utils = require './utils'
{ComposerExtension} = require 'nylas-exports'

rawBodies = {}

class MarkdownComposerExtension extends ComposerExtension

  @applyTransformsForSending: ({draftBodyRootNode, draft}) ->
    rawBodies[draft.clientId] = draftBodyRootNode.innerHTML
    draftBodyRootNode.innerHTML = marked(draftBodyRootNode.innerText)

  @unapplyTransformsForSending: ({draftBodyRootNode, draft}) ->
    if rawBodies[draft.clientId]
      draftBodyRootNode.innerHTML = rawBodies[draft.clientId]

module.exports = MarkdownComposerExtension

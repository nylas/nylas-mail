marked = require 'marked'
Utils = require './utils'
{ComposerExtension} = require 'mailspring-exports'

rawBodies = {}

class MarkdownComposerExtension extends ComposerExtension

  @applyTransformsForSending: ({draftBodyRootNode, draft}) ->
    rawBodies[draft.id] = draftBodyRootNode.innerHTML
    draftBodyRootNode.innerHTML = marked(draftBodyRootNode.innerText)

  @unapplyTransformsForSending: ({draftBodyRootNode, draft}) ->
    if rawBodies[draft.id]
      draftBodyRootNode.innerHTML = rawBodies[draft.id]

module.exports = MarkdownComposerExtension

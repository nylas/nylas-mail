_ = require 'underscore'
{deprecate} = require '../deprecate-utils'
DOMUtils = require '../dom-utils'

ComposerExtensionAdapter = (extension) ->

  if extension.onInput?
    origInput = extension.onInput
    extension.onContentChanged = (editableNode, selection, mutations) ->
      origInput(editableNode)

    extension.onInput = deprecate(
      "DraftStoreExtension.onInput",
      "ComposerExtension.onContentChanged",
      extension,
      extension.onContentChanged
    )

  if extension.onTabDown?
    origKeyDown = extension.onKeyDown
    extension.onKeyDown = (editableNode, selection, event) ->
      if event.key is "Tab"
        range = DOMUtils.getRangeInScope(editableNode)
        extension.onTabDown(editableNode, range, event)
      else
        origKeyDown?(event, editableNode, selection)

    extension.onKeyDown = deprecate(
      "DraftStoreExtension.onTabDown",
      "ComposerExtension.onKeyDown",
      extension,
      extension.onKeyDown
    )

  if extension.onMouseUp?
    origOnClick = extension.onClick
    extension.onClick = (editableNode, selection, event) ->
      range = DOMUtils.getRangeInScope(editableNode)
      extension.onMouseUp(editableNode, range, event)
      origOnClick?(event, editableNode, selection)

    extension.onClick = deprecate(
      "DraftStoreExtension.onMouseUp",
      "ComposerExtension.onClick",
      extension,
      extension.onClick
    )

  return extension

module.exports = ComposerExtensionAdapter

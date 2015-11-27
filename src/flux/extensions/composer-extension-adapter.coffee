_ = require 'underscore'
{deprecate} = require '../../deprecate-utils'
DOMUtils = require '../../dom-utils'

ComposerExtensionAdapter = (extension) ->

  if extension.onInput?.length <= 2
    origInput = extension.onInput
    extension.onInput = (event, editableNode, selection) ->
      origInput(editableNode, event)

    extension.onInput = deprecate(
      "DraftStoreExtension.onInput",
      "ComposerExtension.onInput",
      extension,
      extension.onInput
    )

  if extension.onTabDown?
    origKeyDown = extension.onKeyDown
    extension.onKeyDown = (event, editableNode, selection) ->
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
    extension.onClick = (event, editableNode, selection) ->
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

_ = require 'underscore'
{deprecate} = require '../deprecate-utils'
DOMUtils = require '../dom-utils'

ComposerExtensionAdapter = (extension) ->

  if extension.onInput?
    origInput = extension.onInput
    extension.onContentChanged = (editor, mutations) ->
      origInput(editor.rootNode)

    extension.onInput = deprecate(
      "DraftStoreExtension.onInput",
      "ComposerExtension.onContentChanged",
      extension,
      extension.onContentChanged
    )

  if extension.onTabDown?
    origKeyDown = extension.onKeyDown
    extension.onKeyDown = (editor, event) ->
      if event.key is "Tab"
        range = DOMUtils.getRangeInScope(editor.rootNode)
        extension.onTabDown(editor.rootNode, range, event)
      else
        origKeyDown?(event, editor.rootNode, editor.currentSelection())

    extension.onKeyDown = deprecate(
      "DraftStoreExtension.onTabDown",
      "ComposerExtension.onKeyDown",
      extension,
      extension.onKeyDown
    )

  if extension.onMouseUp?
    origOnClick = extension.onClick
    extension.onClick = (editor, event) ->
      range = DOMUtils.getRangeInScope(editor.rootNode)
      extension.onMouseUp(editor.rootNode, range, event)
      origOnClick?(event, editor.rootNode, editor.currentSelection())

    extension.onClick = deprecate(
      "DraftStoreExtension.onMouseUp",
      "ComposerExtension.onClick",
      extension,
      extension.onClick
    )

  return extension

module.exports = ComposerExtensionAdapter

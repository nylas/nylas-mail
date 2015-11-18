{DraftStore, DOMUtils, ContenteditablePlugin} = require 'nylas-exports'

class ComposerExtensionsPlugin extends ContenteditablePlugin
  @onInput: (event, editableNode, selection, innerStateProxy) ->
    for extension in DraftStore.extensions()
      extension.onInput?(editableNode, event)

  @onKeyDown: (event, editableNode, selection, innerStateProxy) ->
    if event.key is "Tab"
      range = DOMUtils.getRangeInScope(editableNode)
      for extension in DraftStore.extensions()
        extension.onTabDown?(editableNode, range, event)

  @onShowContextMenu: (args...) ->
    for extension in DraftStore.extensions()
      extension.onShowContextMenu?(args...)

  @onClick: (event, editableNode, selection, innerStateProxy) ->
    range = DOMUtils.getRangeInScope(editableNode)
    return unless range
    try
      for extension in DraftStore.extensions()
        extension.onMouseUp?(editableNode, range, event)
    catch e
      console.error('DraftStore extension raised an error: '+e.toString())

module.exports = ComposerExtensionsPlugin

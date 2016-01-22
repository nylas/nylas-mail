{DOMUtils, ContenteditableExtension} = require 'nylas-exports'
ToolbarButtons = require './toolbar-buttons'

# This contains the logic to declaratively render the core
# <ToolbarButtons> component in a <FloatingToolbar>
class ToolbarButtonManager extends ContenteditableExtension

  # See the {EmphasisFormattingExtension} and {LinkManager} and other
  # extensions for toolbarButtons.
  @toolbarButtons: => []

  @toolbarComponentConfig: ({toolbarState}) =>
    return null if toolbarState.dragging or toolbarState.doubleDown
    return null unless toolbarState.selectionSnapshot
    return null if toolbarState.selectionSnapshot.isCollapsed

    buttonConfigs = @_toolbarButtonConfigs(toolbarState)

    return {
      component: ToolbarButtons
      props:
        buttonConfigs: buttonConfigs
      locationRefNode: DOMUtils.getRangeInScope(toolbarState.editableNode)
      width: buttonConfigs.length * 28.5
    }

  @_toolbarButtonConfigs: (toolbarState) ->
    {extensions, atomicEdit} = toolbarState
    buttonConfigs = []

    for extension in extensions
      try
        extensionConfigs = extension.toolbarButtons?({toolbarState}) ? []
        continue if extensionConfigs.length is 0
        extensionConfigs.map (config) ->
          fn = config.onClick ? ->
          config.onClick = (event) -> atomicEdit(fn, {event})
          return config
        buttonConfigs = buttonConfigs.concat(extensionConfigs)
      catch error
        NylasEnv.emitError(error)

    return buttonConfigs


module.exports = ToolbarButtonManager

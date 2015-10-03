{ComponentRegistry, DraftStore, React} = require 'nylas-exports'
TemplatePicker = require './template-picker'
TemplateStatusBar = require './template-status-bar'
Extension = require './template-draft-extension'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    ComponentRegistry.register TemplatePicker,
      role: 'Composer:ActionButton'

    ComponentRegistry.register TemplateStatusBar,
      role: 'Composer:Footer'

    DraftStore.registerExtension(Extension)

  deactivate: ->
    ComponentRegistry.unregister(TemplatePicker)
    ComponentRegistry.unregister(TemplateStatusBar)
    DraftStore.unregisterExtension(Extension)

  serialize: -> @state

React = require "react"
{ComponentRegistry, DraftStore} = require 'inbox-exports'
TemplatePicker = require './template-picker'
TemplateStatusBar = require './template-status-bar'
Extension = require './draft-extension'
_ = require 'underscore-plus'

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

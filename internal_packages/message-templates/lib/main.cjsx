React = require "react"
{ComponentRegistry} = require('inbox-exports')
TemplatePicker = require './template-picker'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register our menu item in the composer footer
    ComponentRegistry.register
      name: 'TemplatePicker'
      role: 'Composer:Footer'
      view: TemplatePicker


  deactivate: ->

  serialize: -> @state

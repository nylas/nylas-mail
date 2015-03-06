React = require "react"
MessageList = require "./message-list"
MessageToolbarItems = require "./message-toolbar-items.cjsx"
{ComponentRegistry} = require 'inbox-exports'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    ComponentRegistry.register
      name: 'MessageToolbarItems'
      role: 'MessageList:Toolbar'
      view: MessageToolbarItems

    ComponentRegistry.register
      name: 'MessageList'
      role: 'ThreadList:Right'
      view: MessageList

  deactivate: ->
    ComponentRegistry.unregister 'MessageToolbarItems'
    ComponentRegistry.unregister 'MessageList'

  serialize: -> @state

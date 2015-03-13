React = require "react"
MessageList = require "./message-list"
MessageToolbarItems = require "./message-toolbar-items.cjsx"
{ComponentRegistry} = require 'inbox-exports'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    ComponentRegistry.register
      name: 'MessageListSplit'
      role: 'Root:Right'
      mode: 'split'
      view: MessageList

    ComponentRegistry.register
      name: 'MessageToolbarItemsSplit'
      role: 'Root:Right:Toolbar'
      mode: 'split'
      view: MessageToolbarItems

    ComponentRegistry.register
      name: 'MessageList'
      role: 'Thread:Center'
      mode: 'list'
      view: MessageList

    ComponentRegistry.register
      name: 'MessageToolbarItems'
      role: 'Thread:Center:Toolbar'
      mode: 'list'
      view: MessageToolbarItems


  deactivate: ->
    ComponentRegistry.unregister 'MessageToolbarItems'
    ComponentRegistry.unregister 'MessageListSplit'
    ComponentRegistry.unregister 'MessageList'

  serialize: -> @state

React = require "react"
MessageList = require "./message-list"
{ComponentRegistry} = require 'inbox-exports'

{ReplyButton,
 ReplyAllButton,
 ForwardButton,
 ArchiveButton} = require "./core-primary-actions.cjsx"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    ComponentRegistry.register
      name: 'edgehill-reply-button'
      role: 'MessageListPrimaryAction'
      view: ReplyButton
    ComponentRegistry.register
      name: 'edgehill-reply-all-button'
      role: 'MessageListPrimaryAction'
      view: ReplyAllButton
    ComponentRegistry.register
      name: 'edgehill-forward-button'
      role: 'MessageListPrimaryAction'
      view: ForwardButton
    ComponentRegistry.register
      name: 'edgehill-archive-button'
      role: 'MessageListPrimaryAction'
      view: ArchiveButton

    ComponentRegistry.register
      name: 'MessageList'
      role: 'ThreadList:Right'
      view: MessageList

  deactivate: ->
    ComponentRegistry.unregister 'edgehill-reply-button'
    ComponentRegistry.unregister 'edgehill-reply-all-button'
    ComponentRegistry.unregister 'edgehill-forward-button'
    ComponentRegistry.unregister 'edgehill-archive-button'
    ComponentRegistry.unregister 'MessageList'

  serialize: -> @state

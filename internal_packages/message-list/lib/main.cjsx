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

    # Register Message Actions we provide globally
    ComponentRegistry.register
      name: 'edgehill-msg-reply-button'
      role: 'MessageAction'
      view: ReplyButton
    ComponentRegistry.register
      name: 'edgehill-msg-reply-all-button'
      role: 'MessageAction'
      view: ReplyAllButton
    ComponentRegistry.register
      name: 'edgehill-msg-forward-button'
      role: 'MessageAction'
      view: ForwardButton

    unless @item
      @item = document.createElement("div")
      @item.setAttribute("id", "message-list")
      @item.setAttribute("class", "message-list")

      atom.workspace.addColumnItem(@item, "message-and-composer")

      React.render(<MessageList /> , @item)

  deactivate: ->
    ComponentRegistry.unregister 'edgehill-reply-button'
    ComponentRegistry.unregister 'edgehill-reply-all-button'
    ComponentRegistry.unregister 'edgehill-forward-button'
    ComponentRegistry.unregister 'edgehill-archive-button'

    React.unmountComponentAtNode(@item)
    @item.remove()
    @item = null

  serialize: -> @state

React = require "react"
MessageList = require "./message-list"
MessageToolbarItems = require "./message-toolbar-items"
MessageSubjectItem = require "./message-subject-item"
{ComponentRegistry} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

DownButton = React.createClass
  render: ->
    <div className="message-toolbar-arrow down" onClick={@_onClick}>
      <RetinaImg name="toolbar-down-arrow.png"/>
    </div>

  _onClick: ->
    atom.commands.dispatch(document.body, 'application:next-item')

UpButton = React.createClass
  render: ->
    <div className="message-toolbar-arrow up" onClick={@_onClick}>
      <RetinaImg name="toolbar-up-arrow.png"/>
    </div>

  _onClick: ->
    atom.commands.dispatch(document.body, 'application:previous-item')


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

    ComponentRegistry.register
      name: 'MessageSubjectItem'
      role: 'Thread:Center:Toolbar'
      mode: 'list'
      view: MessageSubjectItem

    ComponentRegistry.register
      name: 'DownButton'
      role: 'Thread:Right:Toolbar'
      mode: 'list'
      view: DownButton

    ComponentRegistry.register
      name: 'UpButton'
      role: 'Thread:Right:Toolbar'
      mode: 'list'
      view: UpButton


  deactivate: ->
    ComponentRegistry.unregister 'MessageToolbarItems'
    ComponentRegistry.unregister 'MessageListSplit'
    ComponentRegistry.unregister 'MessageList'

  serialize: -> @state

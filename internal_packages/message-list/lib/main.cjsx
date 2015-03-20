React = require "react"
MessageList = require "./message-list"
MessageToolbarItems = require "./message-toolbar-items"
MessageSubjectItem = require "./message-subject-item"
{ComponentRegistry, WorkspaceStore} = require 'inbox-exports'
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
      name: 'MessageList'
      view: MessageList
      location: WorkspaceStore.Location.MessageList

    ComponentRegistry.register
      name: 'MessageToolbarItems'
      view: MessageToolbarItems
      location: WorkspaceStore.Location.MessageList.Toolbar

    ComponentRegistry.register
      name: 'MessageSubjectItem'
      view: MessageSubjectItem
      location: WorkspaceStore.Location.MessageList.Toolbar

    ComponentRegistry.register
      name: 'DownButton'
      mode: 'list'
      view: DownButton
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right

    ComponentRegistry.register
      name: 'UpButton'
      mode: 'list'
      view: UpButton
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right


  deactivate: ->
    ComponentRegistry.unregister 'MessageToolbarItems'
    ComponentRegistry.unregister 'MessageSubjectItem'
    ComponentRegistry.unregister 'MessageList'
    ComponentRegistry.unregister 'DownButton'
    ComponentRegistry.unregister 'UpButton'

  serialize: -> @state

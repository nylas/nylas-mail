MessageList = require "./message-list"
MessageToolbarItems = require "./message-toolbar-items"
MessageSubjectItem = require "./message-subject-item"
{ComponentRegistry,
 WorkspaceStore} = require 'inbox-exports'
SidebarThreadParticipants = require "./sidebar-thread-participants"

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
      name: 'SidebarThreadParticipants'
      location: WorkspaceStore.Location.MessageListSidebar
      view: SidebarThreadParticipants

  deactivate: ->
    ComponentRegistry.unregister 'MessageToolbarItems'
    ComponentRegistry.unregister 'MessageSubjectItem'
    ComponentRegistry.unregister 'MessageList'

  serialize: -> @state

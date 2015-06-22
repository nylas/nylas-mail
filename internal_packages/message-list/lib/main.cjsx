MessageList = require "./message-list"
MessageToolbarItems = require "./message-toolbar-items"
MessageNavTitle = require "./message-nav-title"
{ComponentRegistry,
 WorkspaceStore} = require 'nylas-exports'
SidebarThreadParticipants = require "./sidebar-thread-participants"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    ComponentRegistry.register MessageList,
      location: WorkspaceStore.Location.MessageList

    ComponentRegistry.register MessageToolbarItems,
      location: WorkspaceStore.Location.MessageList.Toolbar

    ComponentRegistry.register MessageNavTitle,
      location: WorkspaceStore.Location.MessageList.Toolbar

    ComponentRegistry.register SidebarThreadParticipants,
      location: WorkspaceStore.Location.MessageListSidebar

  deactivate: ->
    ComponentRegistry.unregister MessageList
    ComponentRegistry.unregister MessageNavTitle
    ComponentRegistry.unregister MessageToolbarItems

  serialize: -> @state

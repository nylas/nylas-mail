MessageList = require "./message-list"
MessageToolbarItems = require "./message-toolbar-items"
{ComponentRegistry,
 WorkspaceStore} = require 'nylas-exports'
SidebarThreadParticipants = require "./sidebar-thread-participants"

ThreadStarButton = require './thread-star-button'
ThreadArchiveButton = require './thread-archive-button'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    ComponentRegistry.register MessageList,
      location: WorkspaceStore.Location.MessageList

    ComponentRegistry.register MessageToolbarItems,
      location: WorkspaceStore.Location.MessageList.Toolbar

    ComponentRegistry.register SidebarThreadParticipants,
      location: WorkspaceStore.Location.MessageListSidebar

    ComponentRegistry.register ThreadStarButton,
      role: 'message:Toolbar'

    ComponentRegistry.register ThreadArchiveButton,
      role: 'message:Toolbar'

  deactivate: ->
    ComponentRegistry.unregister MessageList
    ComponentRegistry.unregister ThreadStarButton
    ComponentRegistry.unregister ThreadArchiveButton
    ComponentRegistry.unregister MessageToolbarItems
    ComponentRegistry.unregister SidebarThreadParticipants

  serialize: -> @state

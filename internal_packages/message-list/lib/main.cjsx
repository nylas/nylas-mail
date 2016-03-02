MessageList = require "./message-list"
MessageListHiddenMessagesToggle = require './message-list-hidden-messages-toggle'
MessageToolbarItems = require "./message-toolbar-items"
{ComponentRegistry,
 ExtensionRegistry,
 WorkspaceStore} = require 'nylas-exports'

{SidebarContactCard,
 SidebarSpacer,
 SidebarContactList} = require "./sidebar-components"

ThreadStarButton = require './thread-star-button'
ThreadArchiveButton = require './thread-archive-button'
ThreadTrashButton = require './thread-trash-button'
ThreadToggleUnreadButton = require './thread-toggle-unread-button'

AutolinkerExtension = require './plugins/autolinker-extension'
TrackingPixelsExtension = require './plugins/tracking-pixels-extension'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    ComponentRegistry.register MessageList,
      location: WorkspaceStore.Location.MessageList

    ComponentRegistry.register MessageToolbarItems,
      location: WorkspaceStore.Location.MessageList.Toolbar

    ComponentRegistry.register SidebarContactCard,
      location: WorkspaceStore.Location.MessageListSidebar
    ComponentRegistry.register SidebarSpacer,
      location: WorkspaceStore.Location.MessageListSidebar
    ComponentRegistry.register SidebarContactList,
      location: WorkspaceStore.Location.MessageListSidebar

    ComponentRegistry.register ThreadStarButton,
      role: 'message:Toolbar'

    ComponentRegistry.register ThreadArchiveButton,
      role: 'message:Toolbar'

    ComponentRegistry.register ThreadTrashButton,
      role: 'message:Toolbar'

    ComponentRegistry.register ThreadToggleUnreadButton,
      role: 'message:Toolbar'

    ComponentRegistry.register MessageListHiddenMessagesToggle,
      role: 'MessageListHeaders'

    ExtensionRegistry.MessageView.register AutolinkerExtension
    ExtensionRegistry.MessageView.register TrackingPixelsExtension

  deactivate: ->
    ComponentRegistry.unregister MessageList
    ComponentRegistry.unregister ThreadStarButton
    ComponentRegistry.unregister ThreadArchiveButton
    ComponentRegistry.unregister ThreadTrashButton
    ComponentRegistry.unregister ThreadToggleUnreadButton
    ComponentRegistry.unregister MessageToolbarItems
    ComponentRegistry.unregister SidebarContactCard
    ComponentRegistry.unregister SidebarSpacer
    ComponentRegistry.unregister SidebarContactList
    ExtensionRegistry.MessageView.unregister AutolinkerExtension
    ExtensionRegistry.MessageView.unregister TrackingPixelsExtension

  serialize: -> @state

{ComponentRegistry,
 ExtensionRegistry,
 WorkspaceStore} = require 'nylas-exports'

MessageList = require "./message-list"
MessageListHiddenMessagesToggle = require './message-list-hidden-messages-toggle'

SidebarPluginContainer = require "./sidebar-plugin-container"
SidebarParticipantPicker = require './sidebar-participant-picker'

module.exports =
  activate: ->
    # Register Message List Actions we provide globally
    ComponentRegistry.register MessageList,
      location: WorkspaceStore.Location.MessageList

    ComponentRegistry.register SidebarParticipantPicker,
      location: WorkspaceStore.Location.MessageListSidebar

    ComponentRegistry.register SidebarPluginContainer,
      location: WorkspaceStore.Location.MessageListSidebar

    ComponentRegistry.register MessageListHiddenMessagesToggle,
      role: 'MessageListHeaders'

  deactivate: ->
    ComponentRegistry.unregister MessageList
    ComponentRegistry.unregister SidebarPluginContainer
    ComponentRegistry.unregister SidebarParticipantPicker

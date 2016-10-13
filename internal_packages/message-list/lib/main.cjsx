{ComponentRegistry,
 ExtensionRegistry,
 WorkspaceStore,
 DatabaseStore,
 Actions,
 Thread} = require 'nylas-exports'

MessageList = require("./message-list")
MessageListHiddenMessagesToggle = require('./message-list-hidden-messages-toggle').default

SidebarPluginContainer = require "./sidebar-plugin-container"
SidebarParticipantPicker = require('./sidebar-participant-picker').default

module.exports =
  activate: ->
    if NylasEnv.isMainWindow()
      # Register Message List Actions we provide globally
      ComponentRegistry.register MessageList,
        location: WorkspaceStore.Location.MessageList

      ComponentRegistry.register SidebarParticipantPicker,
        location: WorkspaceStore.Location.MessageListSidebar

      ComponentRegistry.register SidebarPluginContainer,
        location: WorkspaceStore.Location.MessageListSidebar

      ComponentRegistry.register MessageListHiddenMessagesToggle,
        role: 'MessageListHeaders'
    else
      # This is for the thread-popout window.
      ComponentRegistry.register(MessageList, {location: WorkspaceStore.Location.Center})
      threadId = NylasEnv.getWindowProps().threadId;
      # We need to locate the thread and focus it so that the MessageList displays it
      DatabaseStore.find(Thread, threadId).then((thread) =>
        Actions.setFocus({collection: 'thread', item: thread})
      )

  deactivate: ->
    ComponentRegistry.unregister MessageList
    ComponentRegistry.unregister SidebarPluginContainer
    ComponentRegistry.unregister SidebarParticipantPicker

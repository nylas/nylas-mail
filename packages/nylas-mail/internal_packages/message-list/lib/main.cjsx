{MailboxPerspective,
 ComponentRegistry,
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
      {threadId, perspectiveJSON} = NylasEnv.getWindowProps()
      ComponentRegistry.register(MessageList, {location: WorkspaceStore.Location.Center})
      # We need to locate the thread and focus it so that the MessageList displays it
      DatabaseStore.find(Thread, threadId).then((thread) =>
        Actions.setFocus({collection: 'thread', item: thread})
      )
      # Set the focused perspective and hide the proper messages
      # (e.g. we should hide deleted items from the inbox, but not from trash)
      Actions.focusMailboxPerspective(MailboxPerspective.fromJSON(perspectiveJSON))
      ComponentRegistry.register MessageListHiddenMessagesToggle,
        role: 'MessageListHeaders'

  deactivate: ->
    ComponentRegistry.unregister MessageList
    ComponentRegistry.unregister SidebarPluginContainer
    ComponentRegistry.unregister SidebarParticipantPicker

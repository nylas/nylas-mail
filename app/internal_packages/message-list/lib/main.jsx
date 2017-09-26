import {
  MailboxPerspective,
  ComponentRegistry,
  WorkspaceStore,
  DatabaseStore,
  Actions,
  Thread,
} from 'mailspring-exports';

import MessageListHiddenMessagesToggle from './message-list-hidden-messages-toggle';
import MessageList from './message-list';
import SidebarPluginContainer from './sidebar-plugin-container';
import SidebarParticipantPicker from './sidebar-participant-picker';

export function activate() {
  if (AppEnv.isMainWindow()) {
    // Register Message List Actions we provide globally
    ComponentRegistry.register(MessageList, {
      location: WorkspaceStore.Location.MessageList,
    });
    ComponentRegistry.register(SidebarParticipantPicker, {
      location: WorkspaceStore.Location.MessageListSidebar,
    });
    ComponentRegistry.register(SidebarPluginContainer, {
      location: WorkspaceStore.Location.MessageListSidebar,
    });
    ComponentRegistry.register(MessageListHiddenMessagesToggle, {
      role: 'MessageListHeaders',
    });
  } else {
    // This is for the thread-popout window.
    const { threadId, perspectiveJSON } = AppEnv.getWindowProps();
    ComponentRegistry.register(MessageList, { location: WorkspaceStore.Location.Center });

    // We need to locate the thread and focus it so that the MessageList displays it
    DatabaseStore.find(Thread, threadId).then(thread =>
      Actions.setFocus({ collection: 'thread', item: thread })
    );

    // Set the focused perspective and hide the proper messages
    // (e.g. we should hide deleted items from the inbox, but not from trash)
    Actions.focusMailboxPerspective(MailboxPerspective.fromJSON(perspectiveJSON));
    ComponentRegistry.register(MessageListHiddenMessagesToggle, {
      role: 'MessageListHeaders',
    });
  }
}

export function deactivate() {
  ComponentRegistry.unregister(MessageList);
  ComponentRegistry.unregister(SidebarPluginContainer);
  ComponentRegistry.unregister(SidebarParticipantPicker);
}

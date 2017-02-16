import {ComponentRegistry, WorkspaceStore} from "nylas-exports";

import ThreadList from './thread-list';
import ThreadListToolbar from './thread-list-toolbar';
import MessageListToolbar from './message-list-toolbar';
import SelectedItemsStack from './selected-items-stack';

import {
  UpButton,
  DownButton,
  TrashButton,
  ArchiveButton,
  MarkAsSpamButton,
  ToggleUnreadButton,
  ToggleStarredButton,
} from "./thread-toolbar-buttons";

export function activate() {
  ComponentRegistry.register(ThreadList, {
    location: WorkspaceStore.Location.ThreadList,
  });

  ComponentRegistry.register(SelectedItemsStack, {
    location: WorkspaceStore.Location.MessageList,
    modes: ['split'],
  });

  // Toolbars
  ComponentRegistry.register(ThreadListToolbar, {
    location: WorkspaceStore.Location.ThreadList.Toolbar,
    modes: ['list'],
  });

  ComponentRegistry.register(MessageListToolbar, {
    location: WorkspaceStore.Location.MessageList.Toolbar,
  });

  ComponentRegistry.register(DownButton, {
    location: WorkspaceStore.Location.MessageList.Toolbar,
    modes: ['list'],
  });

  ComponentRegistry.register(UpButton, {
    location: WorkspaceStore.Location.MessageList.Toolbar,
    modes: ['list'],
  });

  ComponentRegistry.register(ArchiveButton, {
    role: 'ThreadActionsToolbarButton',
  });

  ComponentRegistry.register(TrashButton, {
    role: 'ThreadActionsToolbarButton',
  });

  ComponentRegistry.register(MarkAsSpamButton, {
    role: 'ThreadActionsToolbarButton',
  });

  ComponentRegistry.register(ToggleStarredButton, {
    role: 'ThreadActionsToolbarButton',
  });

  ComponentRegistry.register(ToggleUnreadButton, {
    role: 'ThreadActionsToolbarButton',
  });
}

export function deactivate() {
  ComponentRegistry.unregister(ThreadList);
  ComponentRegistry.unregister(SelectedItemsStack);
  ComponentRegistry.unregister(ThreadListToolbar);
  ComponentRegistry.unregister(MessageListToolbar);
  ComponentRegistry.unregister(ArchiveButton);
  ComponentRegistry.unregister(TrashButton);
  ComponentRegistry.unregister(MarkAsSpamButton);
  ComponentRegistry.unregister(ToggleUnreadButton);
  ComponentRegistry.unregister(ToggleStarredButton);
  ComponentRegistry.unregister(UpButton);
  ComponentRegistry.unregister(DownButton);
}

import { WorkspaceStore, ComponentRegistry, Actions } from 'mailspring-exports';
import DraftList from './draft-list';
import DraftListToolbar from './draft-list-toolbar';
import DraftListSendStatus from './draft-list-send-status';
import { DraftDeleteButton } from './draft-toolbar-buttons';

export function activate() {
  WorkspaceStore.defineSheet('Drafts', { root: true }, { list: ['RootSidebar', 'DraftList'] });
  if (
    AppEnv.savedState.perspective &&
    AppEnv.savedState.perspective.type === 'DraftsMailboxPerspective'
  ) {
    Actions.selectRootSheet(WorkspaceStore.Sheet.Drafts);
  }

  ComponentRegistry.register(DraftList, { location: WorkspaceStore.Location.DraftList });
  ComponentRegistry.register(DraftListToolbar, {
    location: WorkspaceStore.Location.DraftList.Toolbar,
  });
  ComponentRegistry.register(DraftDeleteButton, { role: 'DraftActionsToolbarButton' });
  ComponentRegistry.register(DraftListSendStatus, { role: 'DraftList:DraftStatus' });
}

export function deactivate() {
  ComponentRegistry.unregister(DraftList);
  ComponentRegistry.unregister(DraftListToolbar);
  ComponentRegistry.unregister(DraftDeleteButton);
  ComponentRegistry.unregister(DraftListSendStatus);
}

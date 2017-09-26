import { ComponentRegistry, WorkspaceStore } from 'mailspring-exports';
import ThreadSearchBar from './thread-search-bar';

export const configDefaults = {
  showOnRightSide: false,
};

export function activate() {
  ComponentRegistry.register(ThreadSearchBar, {
    location: WorkspaceStore.Location.ThreadList.Toolbar,
  });
}

export function deactivate() {
  ComponentRegistry.unregister(ThreadSearchBar);
}

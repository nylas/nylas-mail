import {ComponentRegistry, WorkspaceStore} from 'nylas-exports';
import ActivityListButton from './activity-list-button';
import ActivityListStore from './activity-list-store';


export function activate() {
  ComponentRegistry.register(ActivityListButton, {
    location: WorkspaceStore.Location.RootSidebar.Toolbar,
  });
  ActivityListStore.activate();
}


export function deactivate() {
  ComponentRegistry.unregister(ActivityListButton);
}

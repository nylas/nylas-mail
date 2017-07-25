import {ComponentRegistry, WorkspaceStore} from 'nylas-exports';
import {HasTutorialTip} from 'nylas-component-kit';
import ActivityListButton from './activity-list-button';
import ActivityListStore from './activity-list-store';

const ActivityListButtonWithTutorialTip = HasTutorialTip(ActivityListButton, {
  title: "Open and link tracking",
  instructions: "If you've enabled link tracking or read receipts, those events will appear here!",
});

export function activate() {
  ComponentRegistry.register(ActivityListButtonWithTutorialTip, {
    location: WorkspaceStore.Location.RootSidebar.Toolbar,
  });
  ActivityListStore.activate();
}


export function deactivate() {
  ComponentRegistry.unregister(ActivityListButtonWithTutorialTip);
}

import { ComponentRegistry, WorkspaceStore, Actions, ExtensionRegistry } from 'mailspring-exports';
import { HasTutorialTip } from 'mailspring-component-kit';

import ActivityMailboxPerspective from './activity-mailbox-perspective';
import ActivityEventStore from './activity-event-store';
import ActivityListButton from './list/activity-list-button';
import Root from './dashboard/root';

const ActivityListButtonWithTutorialTip = HasTutorialTip(ActivityListButton, {
  title: 'Open and link tracking',
  instructions: "If you've enabled link tracking or read receipts, those events will appear here!",
});

const AccountSidebarExtension = {
  name: 'Activity',

  sidebarItem(accountIds) {
    return {
      id: 'Activity',
      name: 'Activity',
      iconName: 'activity.png',
      perspective: new ActivityMailboxPerspective(accountIds),
    };
  },
};

export function activate() {
  // summary view
  ExtensionRegistry.AccountSidebar.register(AccountSidebarExtension);

  WorkspaceStore.defineSheet(
    'Activity',
    { root: true },
    { list: ['RootSidebar', 'ActivityContent'] }
  );

  ComponentRegistry.register(Root, {
    location: WorkspaceStore.Location.ActivityContent,
  });

  const { perspective } = AppEnv.savedState || {};
  if (perspective && perspective.type === 'ActivityMailboxPerspective') {
    Actions.selectRootSheet(WorkspaceStore.Sheet.Activity);
  }

  // list view in top left
  ComponentRegistry.register(ActivityListButtonWithTutorialTip, {
    location: WorkspaceStore.Location.RootSidebar.Toolbar,
  });
  ActivityEventStore.activate();
}

export function deactivate() {
  // summary view
  ExtensionRegistry.AccountSidebar.unregister(AccountSidebarExtension);
  ComponentRegistry.unregister(Root);

  // list view in top left
  ComponentRegistry.unregister(ActivityListButtonWithTutorialTip);
}

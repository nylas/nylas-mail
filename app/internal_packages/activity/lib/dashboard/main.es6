import {
  Actions,
  WorkspaceStore,
  ComponentRegistry,
  ExtensionRegistry,
  MailboxPerspective,
} from 'mailspring-exports';

import Root from './root';

class ActivityMailboxPerspective extends MailboxPerspective {
  sheet() {
    return WorkspaceStore.Sheet.Activity;
  }
  threads() {
    return null;
  }
  canReceiveThreadsFromAccountIds() {
    return false;
  }
  unreadCount() {
    return 0;
  }
}

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
}

export function deactivate() {
  ExtensionRegistry.AccountSidebar.unregister(AccountSidebarExtension);
  ComponentRegistry.unregister(Root);
}

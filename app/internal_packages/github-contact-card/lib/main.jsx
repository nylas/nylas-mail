import { ComponentRegistry } from 'mailspring-exports';

import GithubContactCardSection from './github-contact-card-section';

/*
All packages must export a basic object that has at least the following 3
methods:

1. `activate` - Actions to take once the package gets turned on.
Pre-enabled packages get activated on Mailspring bootup. They can also be
activated manually by a user.

2. `deactivate` - Actions to take when a package gets turned off. This can
happen when a user manually disables a package.
*/
export function activate() {
  // Register our sidebar so that it appears in the Message List sidebar.
  // This sidebar is to the right of the Message List in both split pane mode
  // and list mode.
  ComponentRegistry.register(GithubContactCardSection, {
    role: 'MessageListSidebar:ContactCard',
  });
}

export function deactivate() {
  ComponentRegistry.unregister(GithubContactCardSection);
}

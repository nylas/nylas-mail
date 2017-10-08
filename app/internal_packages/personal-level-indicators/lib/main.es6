import { ComponentRegistry } from 'mailspring-exports';
import PersonalLevelIcon from './personal-level-icon';

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
  ComponentRegistry.register(PersonalLevelIcon, {
    role: 'ThreadListIcon',
  });
}

export function deactivate() {
  ComponentRegistry.unregister(PersonalLevelIcon);
}

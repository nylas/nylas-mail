/*
This package displays a "Vew on Github Button" whenever the message you're
looking at contains a "view it on Github" link.

This is the entry point of an Mailspring package. All packages must have a file
called `main` in their `/lib` folder.

The `activate` method of the package gets called when it is activated.
This happens during Mailspring's bootup. It can also happen when a user manually
enables your package.

Nearly all Mailspring packages have similar `activate` methods. The most common
action is to register a {React} component with the {ComponentRegistry}

See more details about how this works in the {ComponentRegistry}
documentation.

In this case the `ViewOnGithubButton` React Component will get rendered
whenever the `"MessageList:ThreadActionsToolbarButton"` region gets rendered.

Since the `ViewOnGithubButton` doesn't know who owns the
`"MessageList:ThreadActionsToolbarButton"` region, or even when or where it will be rendered, it
has to load its internal `state` from the `GithubStore`.

The `GithubStore` is responsible for figuring out what message you're
looking at, if it has a relevant Github link, and what that link is. Once
it figures that out, it makes that data available for the
`ViewOnGithubButton` to display.
*/

import { ComponentRegistry } from 'mailspring-exports';
import ViewOnGithubButton from './view-on-github-button';

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
  ComponentRegistry.register(ViewOnGithubButton, {
    role: 'ThreadActionsToolbarButton',
  });
}

export function deactivate() {
  ComponentRegistry.unregister(ViewOnGithubButton);
}

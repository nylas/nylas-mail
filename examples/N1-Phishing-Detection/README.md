## Phishing Detection

A sample package for Nylas Mail to detect simple phishing attempts. This package display a simple warning if
a message's originating address is different from its return address. The warning looks like this:

![screenshot](./screenshot.png)

#### Install this plugin

1. Download and run N1

2. From the menu, select `Developer > Install a Package Manually...`
   The dialog will default to this examples directory. Just choose the
   package to install it!

   > When you install packages, they're moved to `~/.nylas/packages`,
   > and N1 runs `apm install` on the command line to fetch dependencies
   > listed in the package's `package.json`

#### Who is this for?

This package is our slimmest example package. It's annotated for developers who have no experience with React, Flux, Electron, or N1.

#### To build documentation (the manual way)

```
cjsx-transform lib/main.cjsx > docs/main.coffee
docco docs/main.coffee
rm docs/main.coffee
```

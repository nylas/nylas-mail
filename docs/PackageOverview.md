---
Title:   Building a Package
Section: Getting Started
---

Packages lie at the heart of Nylas Mail. Each part of the core experience is a separate package that uses the Nilas Package API to add functionality to the client. Want to make a read-only mail client? Remove the core `Composer` package and you'll see reply buttons and composer functionality disappear.

Let's explore the files in a simple package that adds a Translate option to the Composer. When you tap the Translate button, we'll display a popup menu with a list of languages. When you pick a language, we'll make a web request and convert your reply into the desired language.

#####Package Structure

Each package is defined by a `package.json` file that includes it's name, version and dependencies. Our `translate` package uses [React](https://facebook.github.io/react/) and the Node [request](https://github.com/request/request) library.

```
{
  "name": "translate",
  "version": "0.1.0",
  "main": "./lib/main",
  "description": "An example package for Nylas Mail",
  "license": "Proprietary",
  "engines": {
    "atom": "*"
  },
  "dependencies": {
    "react": "^0.12.2",
    "request": "^2.53"
  }
}

```

Our package also contains source files, a spec file with complete tests for the behavior the package adds, and a stylesheet for CSS.

```
- package.json
- lib/
   - main.cjsx
- spec/
   - main-spec.coffee
- stylesheets/
   - translate.less
```

`package.json` lists `lib/main` as the root file of our package. As our package expands, we can add other source files. Since Nylas Mail runs NodeJS, you can `require` other source files, Node packages, etc. Inside `main.cjsx`, there are two important functions being exported:

```coffee
module.exports =

  ##
  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  #
  activate: (@state) ->
    ComponentRegistry.register TranslateButton,
      role: 'Composer:ActionButton'

  ##
  # Serialize is called when your package is about to be unmounted.
  # You can return a state object that will be passed back to your package
  # when it is re-activated.
  #
  serialize: ->
  	{}

  ##
  # This optional method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  deactivate: ->
    ComponentRegistry.unregister('TranslateButton')
```


> Nylas Mail uses CJSX, a Coffeescript version of JSX, which makes it easy to express Virtual DOM in React `render` methods! You may want to add the [Babel](https://github.com/babel/babel-sublime) plugin to Sublime Text, or the [CJSX Language](https://atom.io/packages/language-cjsx) for syntax highlighting.


#####Package Stylesheets

Style sheets for your package should be placed in the _styles_ directory.
Any style sheets in this directory will be loaded and attached to the DOM when
your package is activated. Style sheets can be written as CSS or [Less], but
Less is recommended.

Ideally, you won't need much in the way of styling. We've provided a standard
set of components which define both the colors and UI elements for any package
that fits into Nylas Mail seamlessly.

If you _do_ need special styling, try to keep only structural styles in the
package stylesheets. If you _must_ specify colors and sizing, these should be
taken from the active theme's [ui-variables.less][ui-variables]. For more
information, see the [theme variables docs][theme-variables]. If you follow this
guideline, your package will look good out of the box with any theme!

An optional `stylesheets` array in your _package.json_ can list the style sheets
by name to specify a loading order; otherwise, all style sheets are loaded.

###Installing a Package

Nylas Mail ships with many packages already bundled with the application. When the application launches, it looks for additional packages in `~/.nylas/packages`. Each package you create belongs in it's own directory inside this folder.

In the future, it will be possible to install packages directly from within the client.

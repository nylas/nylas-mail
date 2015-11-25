---
Title:   Building a Package
Section: Guides
Order:   1
---

Packages lie at the heart of N1. Each part of the core experience is a separate package that uses the Nylas Package API to add functionality to the client. Want to make a read-only mail client? Remove the core `Composer` package and you'll see reply buttons and composer functionality disappear.

Let's explore the files in a simple package that adds a Translate option to the Composer. When you tap the Translate button, we'll display a popup menu with a list of languages. When you pick a language, we'll make a web request and convert your reply into the desired language.

### Package Structure

Each package is defined by a `package.json` file that includes its name, version and dependencies. Packages may also declare dependencies which are loaded from npm - in this case, the [request](https://github.com/request/request) library. You'll need to `npm install` these dependencies locally when developing the package.

```
{
  "name": "translate",
  "version": "0.1.0",
  "main": "./lib/main",
  "description": "An example package for N1",
  "license": "GPLv3",
  "engines": {
    "nylas": ">=0.3.0 <0.5.0"
  },
  "dependencies": {
    "request": "^2.53"
  }
}

```

Our package also contains source files, a spec file with complete tests for the behavior the package adds, and a stylesheet for CSS:

```
- package.json
- lib/
   - main.coffee
   - translate-button.cjsx
- spec/
   - main-spec.coffee
- stylesheets/
   - translate.less
```

`package.json` lists `lib/main` as the root file of our package. Since N1 runs NodeJS, we can `require` other source files, Node packages, etc.

N1 can read `js`, `coffee`, `jsx`, and `cjsx` files automatically.

Inside `main.coffee`, there are three important functions being exported:

```coffee
require './translate-button'

module.exports =

  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  #
  activate: (@state) ->
    ComponentRegistry.register TranslateButton,
      role: 'Composer:ActionButton'

  # Serialize is called when your package is about to be unmounted.
  # You can return a state object that will be passed back to your package
  # when it is re-activated.
  #
  serialize: ->
  	{}

  # This optional method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  #
  deactivate: ->
    ComponentRegistry.unregister(TranslateButton)
```


> N1 uses CJSX, a CoffeeScript version of JSX, which makes it easy to express Virtual DOM in React `render` methods! You may want to add the [Babel](https://github.com/babel/babel-sublime) plugin to Sublime Text, or the [CJSX Language](https://atom.io/packages/language-cjsx) for syntax highlighting.


### Package Stylesheets

Style sheets for your package should be placed in the _styles_ directory. Any style sheets in this directory will be loaded and attached to the DOM when your package is activated. Style sheets can be written as CSS or [Less](http://lesscss.org/), but Less is recommended.

Ideally, you won't need much in the way of styling. We've provided a standard set of components which define both the colors and UI elements for any package that fits into N1 seamlessly.

If you _do_ need special styling, try to keep only structural styles in the package stylesheets. If you _must_ specify colors and sizing, these should be taken from the active theme's [ui-variables.less][ui-variables]. For more information, see the [theme variables docs][theme-variables]. If you follow this guideline, your package will look good out of the box with any theme!

An optional `stylesheets` array in your `package.json` can list the style sheets by name to specify a loading order; otherwise, all style sheets are loaded.

### Package Assets

Many packages need other static files, like images. You can add static files anywhere in your package directory, and reference them at runtime using the `nylas://` url scheme:

```
<img src="nylas://my-package-name/assets/goofy.png">

a = new Audio()
a.src = "nylas://my-package-name/sounds/bloop.mp3"
a.play()
```

### Installing a Package

N1 ships with many packages already bundled with the application. When the application launches, it looks for additional packages in `~/.nylas/dev/packages`. Each package you create belongs in its own directory inside this folder.

In the future, it will be possible to install packages directly from within the client.

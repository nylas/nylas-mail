_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
classNames = require 'classnames'

###
Public: Easily respond to keyboard shortcuts

A keyboard shortcut has two parts to it:

1. A mapping between keyboard actions and a command
2. A mapping between a command and a callback handler


## Mapping keys to commands (not handled by this component)

The **keyboard -> command** mapping is defined in a separate `.cson` file.
A majority of the commands your component would want to listen to you have
already been defined by core N1 defaults, as well as custom user
overrides. See 'keymaps/base.cson' for more information.

You can define additional, custom keyboard -> command mappings in your own
package-specific keymap `.cson` file. The file can be named anything but
must exist in a folder called `keymaps` in the root of your package's
directory.


## Mapping commands to callbacks (handled by this component)

When a keystroke sequence matches a binding in a given context, a custom
DOM event with a type based on the command is dispatched on the target of
the keyboard event.

That custom DOM event (whose type is the command you want to listen to)
will propagate up from its original target. That original target may or
may not be a descendent of your <KeyCommandsRegion> component.

Frequently components will want to listen to a keyboard command regardless
of where it was fired from. For those, use the `globalHandlers` prop. The
DOM event will NOT be passed to `globalHandlers` callbacks.

Components may also want to listen to keyboard commands that originate
within one of their descendents. For those use the `localHandlers` prop.
The DOM event WILL be passed to `localHandlers` callback because it is
sometimes valuable to call `stopPropagataion` on the custom command event.

Props:

- `localHandlers` A mapping between key commands and callbacks for key command events that originate within a descendent of this component.
- `globalHandlers` A mapping between key commands and callbacks for key
commands that originate from anywhere and are global in scope.
- `className` The unique class name that shows up in your keymap.cson

Example:

In `my-package/lib/my-component.cjsx`:

```coffee
class MyComponent extends React.Component
  render: ->
    <KeyCommandsRegion globalHandlers={@globalHandlers()} className="my-component">
      <div>... sweet component ...</div>
    </KeyCommandsRegion>

  globalHandlers: ->
    "core:moveDown": @onMoveDown
    "core:selectItem": @onSelectItem

  localHandlers: ->
    "custom:send": (event) => @onSelectItem(); event.stopPropagation()
    "custom:move": @onCustomMove
```

In `my-package/keymaps/my-package.cson`:

```coffee
".my-component":
  "cmd-t": "selectItem"
  "cmd-enter": "sendMessage"
```

###
class KeyCommandsRegion extends React.Component
  @displayName: "KeyCommandsRegion"

  @propTypes:
    className: React.PropTypes.string
    localHandlers: React.PropTypes.object
    globalHandlers: React.PropTypes.object
    globalMenuItems: React.PropTypes.array
    onFocusIn: React.PropTypes.func
    onFocusOut: React.PropTypes.func

  @defaultProps:
    className: ""
    localHandlers: null
    globalHandlers: null
    globalMenuItems: null
    onFocusIn: ->
    onFocusOut: ->

  constructor: ->
    @_lostFocusToElement = null
    @state =
      focused: false

  componentWillReceiveProps: (newProps) ->
    @_unmountListeners()
    @_setupListeners(newProps)

    # Updating menus in particular is expensive, so avoid teardown / re-add if identical
    if not _.isEqual(newProps.globalMenuItems, @props.globalMenuItems)
      @_menuDisposable?.dispose()
      @_menuDisposable = NylasEnv.menu.add(newProps.globalMenuItems)

  componentDidMount: ->
    @_setupListeners(@props)
    if @props.globalMenuItems
      @_menuDisposable = NylasEnv.menu.add(@props.globalMenuItems)

  componentWillUnmount: ->
    @_losingFocusToElement = null
    @_unmountListeners()
    @_menuDisposable?.dispose()
    @_menuDisposable = null

  # When the {KeymapManager} finds a valid keymap in a `.cson` file, it
  # will create a CustomEvent with the command name as its type. That
  # custom event will be fired at the originating target and propogate
  # updwards until it reaches the root window level.
  #
  # An event is scoped in the `.cson` files. Since we use that to
  # determine which keymappings can fire a particular command in a
  # particular scope, we simply need to listen at the root window level
  # here for all commands coming in.
  _setupListeners: (props) ->
    $el = ReactDOM.findDOMNode(@)
    $el.addEventListener('focusin', @_onFocusIn)
    $el.addEventListener('focusout', @_onFocusOut)

    if props.globalHandlers
      @_globalDisposable = NylasEnv.commands.add(document.body, props.globalHandlers)
    if props.localHandlers
      @_localDisposable = NylasEnv.commands.add($el, props.localHandlers)

    window.addEventListener('browser-window-blur', @_onWindowBlur)

  _unmountListeners: ->
    @_globalDisposable?.dispose()
    @_globalDisposable = null
    @_localDisposable?.dispose()
    @_localDisposable = null
    $el = ReactDOM.findDOMNode(@)
    $el.removeEventListener('focusin', @_onFocusIn)
    $el.removeEventListener('focusout', @_onDidFocusOut)
    window.removeEventListener('browser-window-blur', @_onWindowBlur)
    @_goingout = false

  _onWindowBlur: =>
    @setState(focused: false)

  _onFocusIn: (event) =>
    @_lastFocusElement = event.target
    @_losingFocusToElement = null
    @props.onFocusIn(event) if @state.focused is false
    @setState(focused: true)

  _onFocusOut: (event) =>
    @_lastFocusElement = event.target
    @_losingFocusToElement = event.relatedTarget

    # Focus could be lost for a moment and programatically restored. To support
    # old machines with slow CPUs, it's important we wait N frames rather than X
    # msec to see if focus is restored before declaring it "out" for good.
    attempt = =>
      if not @_losingFocusToElement
        @_losingFocusFrames = 0
        return

      @_losingFocusFrames -= 1
      if @_losingFocusFrames is 0
        @_onDefinitelyFocusedOut()
      else
        window.requestAnimationFrame(attempt)

    if !@_losingFocusFrames
      window.requestAnimationFrame(attempt)
    @_losingFocusFrames = 10 # at 60fps, roughly 150ms

  _onDefinitelyFocusedOut: =>
    return unless @_losingFocusToElement
    return unless @state.focused

    # This happens when component that used to have the focus is
    # unmounted. An example is the url input field of the
    # FloatingToolbar in the Composer's Contenteditable
    return if ReactDOM.findDOMNode(@).contains(document.activeElement)

    # This prevents the strange effect of an input appearing to have focus
    # when the element receiving focus does not support selection (like a
    # div with tabIndex=-1)
    if @_losingFocusToElement.tagName isnt 'INPUT'
      document.getSelection().empty()

    @props.onFocusOut(@_lastFocusElement)
    @setState({focused: false})
    @_losingFocusToElement = null

  render: ->
    classname = classNames
      'key-commands-region': true
      'focused': @state.focused
    otherProps = _.omit(@props, Object.keys(@constructor.propTypes))

    <div className="#{classname} #{@props.className}" {...otherProps}>
      {@props.children}
    </div>

module.exports = KeyCommandsRegion

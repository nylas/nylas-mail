React = require 'react/addons'
_ = require 'underscore'
{CompositeDisposable} = require 'event-kit'

###
Public: The Popover component makes it easy to display a sheet or popup menu when the
user clicks the React element provided as `buttonComponent`. In Edgehill, the Popover
component is used to create rich dropdown menus, detail popups, etc. with consistent
look and feel and behavior.

The Popover component handles:

- Rendering it's children when you click `buttonComponent`, and dismissing it's
  children when you click outside the popover or press the Escape key.

- Automatically focusing the item with the lowest tabIndex inside the popover

## Input Focus

If your Popover contains an input, like a search bar, give it a tabIndex and
Popover will automatically focus it when the popover is opened.

## Advanced Use

If you don't want to use the Popover in conjunction with a triggering button,
you can manually call `open()` and `close()` to display it. A typical scenario
looks like this:

```coffeescript
render: =>
  <Popover ref="myPopover"> Popover Contents </Popover>

showMyPopover: =>
  @refs.myPopover.open()

```

Section: Component Kit
###
class Popover extends React.Component

  ###
  Public: React `props` supported by Popover:

   - `buttonComponent` The React element that will be rendered in place of the
     Popover and trigger it to appear. This is typically a button or call-to-action for
     opening the popover. Popover wraps this item in a <div> with an onClick handler.

   - `children` The React elements that should appear when the Popover is opened.
     They're automatically wrapped in a `<div class="popover">`, which applies standard
     shadowing and styles.

  - `direction` Defaults to 'up'. You can also pass 'down' to make the Popover float beneath
    the button component.

  Events

  - `onOpened` A {Function} that will be called when the popover is opened.

  ###
  @propTypes =
    buttonComponent: React.PropTypes.element
    direction: React.PropTypes.string

  @defaultProps =
    direction: 'up'

  constructor: (@props) ->
    @state =
      showing: false

  componentDidMount: =>
    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add '.popover-container', {
      'popover:close': => @close()
    }

  componentWillUnmount: =>
    @subscriptions?.dispose()

  open: =>
    @setState
      showing: true
    if @props.onOpened?
      @props.onOpened()

  close: =>
    @setState
      showing: false

  render: =>
    wrappedButtonComponent = []
    if @props.buttonComponent
      wrappedButtonComponent = <div onClick={@_onClick}>{@props.buttonComponent}</div>

    popoverComponent = []
    if @state.showing
      popoverStyle =
        'position': 'absolute'
        'left': '50%'
        'zIndex': 40
      pointerStyle =
        'position': 'absolute'
        'marginLeft': '50%'
        'zoom': 0.5
        'width': 45
        'height': 21
        'zIndex': 0

      if @props.direction is 'up'
        popoverStyle = _.extend popoverStyle,
          'transform': 'translate(-50%,-100%)'
          'top': -10,
        pointerStyle = _.extend pointerStyle,
          'transform': 'translateX(-50%)'
          'bottom': -10

      else if @props.direction is 'down'
        popoverStyle = _.extend popoverStyle,
          'transform': 'translate(-50%,15px)'
          'top': '100%'
        pointerStyle = _.extend pointerStyle,
          'transform': 'rotateX(180deg)'
          'top': -10
          'left':-12

      popoverComponent = <div ref="popover" className={"popover popover-"+@props.direction} style={popoverStyle}>
        {@props.children}
        <div className="popover-pointer" style={pointerStyle}></div>
      </div>

    <div className={"popover-container "+@props.className} onBlur={@_onBlur} ref="container">
      {wrappedButtonComponent}
      {popoverComponent}
    </div>

  _onClick: =>
    if not @state.showing
      @open()
      setTimeout =>
        # Automatically focus the element inside us with the lowest tab index
        node = React.findDOMNode(@refs.popover)

        # _.sortBy ranks in ascending numerical order.
        matches = _.sortBy node.querySelectorAll("[tabIndex], input"), (node) ->
          if node.tabIndex > 0
            return node.tabIndex
          else if node.nodeName is "INPUT"
            return 1000000
          else return 1000001
        matches[0]?.focus()
    else
      @close()

  _onBlur: (event) =>
    target = event.nativeEvent.relatedTarget
    if target? and React.findDOMNode(@refs.container).contains(target)
      return
    @setState
      showing:false

module.exports = Popover

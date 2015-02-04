React = require 'react/addons'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'event-kit'

###
The Popover component makes it easy to display a sheet or popup menu when the user
clicks the React element provided as `buttonComponent`. In Edgehill, the Popover
component is used to create rich dropdown menus, detail popups, etc. with consistent
look and feel and behavior.

The Popover manages two React components:

- `buttonComponent`: This is typically a button or call-to-action for opening the
  popover. Popover wraps this item in a <div> with an onClick handler.

- `props.children`: Any components you put inside the Popover component are shown
  when you click the `buttonComponent`. They're automatically wrapped in a
  `<div class="popover">`, which applies standard shadowing and styles.

The Popover component handles:

- Rendering it's children when you click `buttonComponent`, and dismissing it's
  children when you click outside the popover or press the Escape key.

- Automatically focusing the item with the lowest tabIndex inside the popover

Input Focus
-----------
If your Popover contains an input, like a search bar, give it a tabIndex and
Popover will automatically focus it when the popover is opened.

Advanced Use
------------
If you don't want to use the Popover in conjunction with a triggering button,
you can manually call `open()` and `close()` to display it. A typical scenario
looks like this:

```
render: ->
  <Popover ref="myPopover"> Popover Contents </Popover>

showMyPopover: ->
  @refs.myPopover.open()

```

###
module.exports =
Popover = React.createClass

  propTypes:
    buttonComponent: React.PropTypes.element,

  getInitialState: ->
    showing: false

  componentDidMount: ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add '.popover-container', {
      'popover:close': => @close()
    }

  componentWillUnmount: ->
    @subscriptions?.dispose()

  open: ->
    @setState
      showing: true

  close: ->
    @setState
      showing: false

  render: ->
    wrappedButtonComponent = []
    if @props.buttonComponent
      wrappedButtonComponent = <div onClick={@_onClick}>{@props.buttonComponent}</div>
    
    popoverComponent = []
    if @state.showing
      popoverComponent = <div ref="popover" className="popover">{@props.children}</div>

    <div className={"popover-container "+@props.className} onBlur={@_onBlur} tabIndex="1" ref="container">
      {wrappedButtonComponent}
      {popoverComponent}
    </div>

  _onClick: ->
    @setState
      showing:true

    setTimeout =>
      # Automatically focus the element inside us with the lowest tab index
      node = @refs.popover.getDOMNode()
      matches = _.sortBy node.querySelectorAll("[tabIndex]"), (a,b) -> a.tabIndex < b.tabIndex
      matches[0].focus() if matches[0]

  _onBlur: (event) ->
    target = event.nativeEvent.relatedTarget
    if target? and @refs.container.getDOMNode().contains(target)
      return
    @setState
      showing:false


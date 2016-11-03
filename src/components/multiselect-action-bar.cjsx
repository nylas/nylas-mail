React = require "react"
ReactCSSTransitionGroup = require 'react-addons-css-transition-group'
_ = require 'underscore'

{Utils, Actions} = require "nylas-exports"
InjectedComponentSet = require './injected-component-set'
Flexbox = require('./flexbox').default

###
Public: MultiselectActionBar is a simple component that can be placed in a {Sheet} Toolbar.
When the provided `dataStore` has a selection, it appears over the other items in the toolbar.

Generally, you wrap {MultiselectActionBar} in your own simple component to provide a dataStore
and other settings:

```coffee
class MultiselectActionBar extends React.Component
  @displayName: 'MultiselectActionBar'

  render: =>
    <MultiselectActionBar
      dataStore={ThreadListStore}
      className="thread-list"
      collection="thread" />
```

The MultiselectActionBar uses the `ComponentRegistry` to find items to display for the given
collection name. To add an item to the bar created in the example above, register it like this:

```coffee
ComponentRegistry.register ThreadBulkTrashButton,
  role: 'thread:Toolbar'
```

Section: Component Kit
###
class MultiselectActionBar extends React.Component
  @displayName: 'MultiselectActionBar'

  ###
  Public: React `props` supported by MultiselectActionBar:

   - `dataStore` An instance of a {ListDataSource}.
   - `collection` The name of the collection. The collection name is used for the text
      that appears in the bar "1 thread selected" and is also used to find components
      in the component registry that should appear in the bar (`thread` => `thread:BulkAtion`)
  ###
  @propTypes:
    collection: React.PropTypes.string.isRequired
    dataSource: React.PropTypes.object

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @setupForProps(@props)

  componentWillReceiveProps: (newProps) =>
    return if _.isEqual(@props, newProps)
    @teardownForProps()
    @setupForProps(newProps)
    @setState(@_getStateFromStores(newProps))

  componentWillUnmount: =>
    @teardownForProps()

  teardownForProps: =>
    return unless @_unsubscribers
    unsubscribe() for unsubscribe in @_unsubscribers

  setupForProps: (props) =>
    @_unsubscribers = []
    @_unsubscribers.push props.dataSource.listen @_onChange

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  render: =>
    <ReactCSSTransitionGroup
      className={"selection-bar"}
      transitionName="selection-bar-absolute"
      component="div"
      transitionLeaveTimeout={200}
      transitionEnterTimeout={200}>
      { if @state.items.length > 0 then @_renderBar() else [] }
    </ReactCSSTransitionGroup>

  _renderBar: =>
    <div className="absolute" key="absolute">
      <div className="inner">
        {@_renderActions()}

        <div className="centered">
          {@_label()}
        </div>

        <button style={order:100}
                className="btn btn-toolbar"
                onClick={@_onClearSelection}>
          Clear Selection
        </button>
      </div>
    </div>

  _renderActions: =>
    return <div></div> unless @props.dataSource
    <InjectedComponentSet matching={role:"#{@props.collection}:Toolbar"}
                          exposedProps={selection: @props.dataSource.selection, items: @state.items} />

  _label: =>
    if @state.items.length > 1
      "#{@state.items.length} #{@props.collection}s selected"
    else if @state.items.length is 1
      "#{@state.items.length} #{@props.collection} selected"
    else
      ""

  _getStateFromStores: (props = @props) =>
    items: props.dataSource.selection.items() ? []

  _onChange: =>
    @setState(@_getStateFromStores())

  _onClearSelection: =>
    @props.dataSource.selection.clear()
    return

module.exports = MultiselectActionBar

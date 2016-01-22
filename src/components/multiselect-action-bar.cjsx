React = require "react/addons"
_ = require 'underscore'

{Utils,
 Actions,
 WorkspaceStore} = require "nylas-exports"
InjectedComponentSet = require './injected-component-set'
TimeoutTransitionGroup = require './timeout-transition-group'
RetinaImg = require './retina-img'
Flexbox = require './flexbox'

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
  role: 'thread:BulkAction'
```

Section: Component Kit
###
class MultiselectActionBar extends React.Component
  @displayName: 'MultiselectActionBar'

  ###
  Public: React `props` supported by MultiselectActionBar:

   - `dataStore` An instance of a {ModelView}.
   - `collection` The name of the collection. The collection name is used for the text
      that appears in the bar "1 thread selected" and is also used to find components
      in the component registry that should appear in the bar (`thread` => `thread:BulkAtion`)
  ###
  @propTypes:
    collection: React.PropTypes.string.isRequired
    dataStore: React.PropTypes.object.isRequired

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
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers

  setupForProps: (props) =>
    @unsubscribers = []
    @unsubscribers.push props.dataStore.listen @_onChange
    @unsubscribers.push WorkspaceStore.listen @_onChange

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  render: =>
    <TimeoutTransitionGroup
      className={"selection-bar"}
      transitionName="selection-bar-absolute"
      component="div"
      leaveTimeout={200}
      enterTimeout={200}>
      { if @state.items.length > 0 then @_renderBar() else [] }
    </TimeoutTransitionGroup>

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
    return <div></div> unless @state.view
    <InjectedComponentSet matching={role:"#{@props.collection}:BulkAction"}
                          exposedProps={selection: @state.view.selection, items: @state.items} />

  _label: =>
    if @state.items.length > 1
      "#{@state.items.length} #{@props.collection}s selected"
    else if @state.items.length is 1
      "#{@state.items.length} #{@props.collection} selected"
    else
      ""

  _getStateFromStores: (props) =>
    props ?= @props
    view = props.dataStore.view()
    items = view?.selection.items() ? []

    return {
      view: view
      items: items
    }

  _onChange: =>
    @setState(@_getStateFromStores())

  _onClearSelection: =>
    @state.view.selection.clear()


module.exports = MultiselectActionBar

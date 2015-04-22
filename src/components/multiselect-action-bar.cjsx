React = require "react/addons"
_ = require 'underscore-plus'

{Actions,
 AddRemoveTagsTask,
 WorkspaceStore} = require "inbox-exports"
RegisteredRegion = require './registered-region'
RetinaImg = require './retina-img'

module.exports =
MultiselectActionBar = React.createClass
  displayName: 'MultiselectActionBar'
  propTypes:
    collection: React.PropTypes.string.isRequired
    dataStore: React.PropTypes.object.isRequired

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @setupForProps(@props)

  componentWillReceiveProps: (newProps) ->
    return if _.isEqual(@props, newProps)
    @teardownForProps()
    @setupForProps(newProps)
    @setState(@_getStateFromStores(newProps))

  componentWillUnmount: ->
    @teardownForProps()

  teardownForProps: ->
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers

  setupForProps: (props) ->
    @unsubscribers = []
    @unsubscribers.push props.dataStore.listen @_onChange
    @unsubscribers.push WorkspaceStore.listen @_onChange

  shouldComponentUpdate: (nextProps, nextState) ->
    @props.collection isnt nextProps.collection or
    @state.count isnt nextState.count or
    @state.view isnt nextState.view or
    @state.type isnt nextState.type

  render: ->
    <div className={@_classSet()}><div className="absolute"><div className="inner">
      {@_renderActions()}

      <div className="centered">
        {@_label()}
      </div>

      <button style={order:100}
              className="btn btn-toolbar"
              onClick={@_onClearSelection}>
        Clear Selection
      </button>
    </div></div></div>

  _renderActions: ->
    return <div></div> unless @state.view
    <RegisteredRegion location={"#{@props.collection}:BulkAction"}
                      selection={@state.view.selection} />

  _label: ->
    if @state.count > 1
      "#{@state.count} #{@props.collection}s selected"
    else if @state.count is 1
      "#{@state.count} #{@props.collection} selected"
    else
      ""

  _classSet: ->
    React.addons.classSet
      "selection-bar": true
      "enabled": @state.count > 0

  _getStateFromStores: (props) ->
    props ?= @props
    view = props.dataStore.view()

    view: view
    count: view?.selection.items().length

  _onChange: ->
    @setState(@_getStateFromStores())

  _onClearSelection: ->
    @state.view.selection.clear()


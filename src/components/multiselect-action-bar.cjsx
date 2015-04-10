React = require "react/addons"
{RetinaImg} = require 'ui-components'
{Actions,
 AddRemoveTagsTask,
 WorkspaceStore,
 ComponentRegistry} = require "inbox-exports"
_ = require 'underscore-plus'

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
    @unsubscribers.push ComponentRegistry.listen @_onChange

  shouldComponentUpdate: (nextProps, nextState) ->
    @props.collection isnt nextProps.collection or
    @state.count isnt nextState.count or
    @state.view isnt nextState.view or
    @state.type isnt nextState.type

  render: ->
    <div className={@_classSet()}><div className="absolute"><div className="inner">
      {@_renderButtonsForItemType()}

      <div className="centered">
        {@_label()}
      </div>

      <button style={order:100}
              className="btn btn-toolbar"
              onClick={@_onClearSelection}>
        Clear Selection
      </button>
    </div></div></div>
  
  _renderButtonsForItemType: ->
    return [] unless @state.view
    (@state.ActionComponents ? []).map ({view, name}) =>
      <view key={name} selection={@state.view.selection} />

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
    ActionComponents: ComponentRegistry.findAllByRole("#{props.collection}:BulkAction")

  _onChange: ->
    @setState(@_getStateFromStores())

  _onClearSelection: ->
    @state.view.selection.clear()


React = require "react/addons"
ThreadListStore = require './thread-list-store'
{RetinaImg} = require 'ui-components'
{Actions, AddRemoveTagsTask} = require "inbox-exports"

module.exports =
ThreadSelectionBar = React.createClass
  displayName: 'ThreadSelectionBar'

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribers = []
    @unsubscribers.push ThreadListStore.listen @_onChange

  componentWillUnmount: ->
    unsubscribe() for unsubscribe in @unsubscribers

  render: ->
    <div className={@_classSet()}><div className="absolute"><div className="inner">
      <button style={order:-100}
              className="btn btn-toolbar"
              data-tooltip="Archive"
              onClick={@_onArchive}>
        <RetinaImg name="toolbar-archive.png" />
      </button>

      <div className="centered">
        {@_label()}
      </div>

      <button style={order:100}
              className="btn btn-toolbar"
              onClick={@_onClearSelection}>
        Clear Selection
      </button>
    </div></div></div>

  _label: ->
    if @state.selected.length > 0
      "#{@state.selected.length} Threads Selected"
    else
      ""

  _classSet: ->
    React.addons.classSet
      "thread-selection-bar": true
      "enabled": @state.selected.length > 0

  _getStateFromStores: ->
    selected: ThreadListStore.view()?.selection.items() ? []

  _onChange: ->
    @setState(@_getStateFromStores())

  _onArchive: ->
    for thread in @state.selected
      task = new AddRemoveTagsTask(thread, ['archive'], ['inbox'])
      Actions.queueTask(task)

  _onClearSelection: ->
    Actions.selectThreads([])

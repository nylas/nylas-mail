_ = require 'underscore-plus'
React = require "react"
{ModelList} = require 'ui-components'
{ComponentRegistry, WorkspaceStore, Actions, DraftStore} = require "inbox-exports"

{DownButton, UpButton} = require "./thread-nav-buttons"
ThreadSelectionBar = require './thread-selection-bar'
ThreadList = require './thread-list'
DraftList = require './draft-list'

RootCenterComponent = React.createClass
  displayName: 'RootCenterComponent'

  getInitialState: ->
    view: WorkspaceStore.selectedView()

  componentDidMount: ->
    @unsubscribe = WorkspaceStore.listen @_onStoreChange

  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    if @state.view is 'threads'
      <ThreadList />
    else
      <DraftList />

  _onStoreChange: ->
    @setState
      view: WorkspaceStore.selectedView()

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register
      view: RootCenterComponent
      name: 'RootCenterComponent'
      location: WorkspaceStore.Location.RootCenter

    ComponentRegistry.register
      name: 'ThreadSelectionBar'
      view: ThreadSelectionBar
      location: WorkspaceStore.Location.RootCenter.Toolbar

    ComponentRegistry.register
      name: 'DownButton'
      mode: 'list'
      view: DownButton
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right

    ComponentRegistry.register
      name: 'UpButton'
      mode: 'list'
      view: UpButton
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right

  deactivate: ->
    ComponentRegistry.unregister 'RootCenterComponent'
    ComponentRegistry.unregister 'DownButton'
    ComponentRegistry.unregister 'UpButton'

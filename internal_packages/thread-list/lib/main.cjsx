_ = require 'underscore-plus'
React = require "react"
{ComponentRegistry, WorkspaceStore} = require "inbox-exports"
ThreadList = require "./thread-list"
DraftList  = require "./draft-list"

RootCenterComponent = React.createClass
  displayName: 'RootCenterComponent'

  getInitialState: ->
    view: WorkspaceStore.selectedView()

  componentDidMount: ->
    @unsubscribe = WorkspaceStore.listen @_onStoreChange

  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    views =
      'threads': ThreadList
      'drafts':  DraftList
    view = views[@state.view]
    <view />
    
  _onStoreChange: ->
    @setState
      view: WorkspaceStore.selectedView()


module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register
      view: RootCenterComponent
      name: 'RootCenterComponent'
      location: WorkspaceStore.Location.RootCenter

React = require 'react'
{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
ActivityBar = require './activity-bar'

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register ActivityBar,
      location: WorkspaceStore.Sheet.Global.Footer

  deactivate: ->
    ComponentRegistry.unregister ActivityBar

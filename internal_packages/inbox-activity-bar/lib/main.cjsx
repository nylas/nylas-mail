React = require 'react'
{ComponentRegistry, WorkspaceStore} = require 'inbox-exports'

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register
      name: 'activity-bar'
      view: require './activity-bar'
      location: WorkspaceStore.Sheet.Global.Footer

  deactivate: ->
    ComponentRegistry.unregister 'activity-bar'

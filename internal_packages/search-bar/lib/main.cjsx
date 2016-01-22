path = require 'path'
{ComponentRegistry, WorkspaceStore, React} = require 'nylas-exports'
SearchBar = require './search-bar'

module.exports =
  configDefaults:
    showOnRightSide: false

  activate: (@state) ->
    ComponentRegistry.register SearchBar,
      location: WorkspaceStore.Location.ThreadList.Toolbar

  deactivate: ->
    ComponentRegistry.unregister SearchBar

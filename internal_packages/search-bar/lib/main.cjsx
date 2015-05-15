path = require 'path'
require 'coffee-react/register'
React = require 'react'
{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
SearchBar = require './search-bar'

module.exports =
  configDefaults:
    showOnRightSide: false

  activate: (@state) ->
    ComponentRegistry.register SearchBar,
      location: WorkspaceStore.Location.ThreadList.Toolbar

  deactivate: ->
    ComponentRegistry.unregister SearchBar

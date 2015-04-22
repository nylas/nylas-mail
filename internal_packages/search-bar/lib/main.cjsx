path = require 'path'
require 'coffee-react/register'
React = require 'react'
{ComponentRegistry, WorkspaceStore} = require 'inbox-exports'
SearchBar = require './search-bar'

module.exports =
  configDefaults:
    showOnRightSide: false

  activate: (@state) ->
    ComponentRegistry.register
      view: SearchBar
      name: 'SearchBar'
      location: WorkspaceStore.Location.ThreadList.Toolbar

  deactivate: ->
    ComponentRegistry.unregister 'SearchBar'

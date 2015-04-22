path = require 'path'
require 'coffee-react/register'
React = require 'react'
{ComponentRegistry, WorkspaceStore} = require 'inbox-exports'

SearchPlaygroundBar = require './search-bar'
SearchPlaygroundSettingsBar = require './search-settings-bar'
SearchPlaygroundBottomBar = require './search-bottom-bar'
SearchResultsList = require './search-results-list'

module.exports =
  configDefaults:
    showOnRightSide: false

  activate: (@state) ->
    WorkspaceStore.defineSheet 'Search', {root: true, supportedModes: ['list'], name: 'Search'},
      list: ['RootSidebar', 'SearchPlayground']

    ComponentRegistry.register
      view: SearchPlaygroundBar
      name: 'SearchPlaygroundBar'
      location: WorkspaceStore.Location.SearchPlayground

    ComponentRegistry.register
      view: SearchPlaygroundBottomBar
      name: 'SearchPlaygroundBottomBar'
      location: WorkspaceStore.Location.SearchPlayground

    ComponentRegistry.register
      view: SearchPlaygroundSettingsBar
      name: 'SearchPlaygroundSettingsBar'
      location: WorkspaceStore.Location.SearchPlayground

    ComponentRegistry.register
      view: SearchResultsList
      name: 'SearchResultsList'
      location: WorkspaceStore.Location.SearchPlayground


  deactivate: ->
    ComponentRegistry.unregister 'SearchBar'

path = require 'path'
require 'coffee-react/register'
React = require 'react'
{ComponentRegistry} = require 'inbox-exports'
SearchBar = require './search-bar'
SearchSettingsBar = require './search-settings-bar'

module.exports =
  configDefaults:
    showOnRightSide: false

  activate: (@state) ->
    ComponentRegistry.register
      view: SearchBar
      name: 'SearchBar'
      role: 'Global:Toolbar'

  deactivate: ->
    ComponentRegistry.unregister 'SearchBar'

React = require 'react'
{ComponentRegistry} = require 'inbox-exports'

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register
      name: 'activity-bar'
      role: 'Global:Footer'
      view: require './activity-bar'

  deactivate: ->
    ComponentRegistry.unregister 'activity-bar'

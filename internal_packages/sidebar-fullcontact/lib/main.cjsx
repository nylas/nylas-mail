_ = require 'underscore-plus'
React = require "react"
SidebarFullContact = require "./sidebar-fullcontact.cjsx"
{ComponentRegistry} = require("inbox-exports")

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register
      name: 'SidebarFullContact'
      view: SidebarFullContact

  deactivate: ->
    ComponentRegistry.unregister('SidebarFullContact')

  serialize: -> @state

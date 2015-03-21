_ = require 'underscore-plus'
React = require "react"
SidebarFullContact = require "./sidebar-fullcontact"
{ComponentRegistry, WorkspaceStore} = require "inbox-exports"

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register
      name: 'SidebarFullContact'
      view: SidebarFullContact
      location: WorkspaceStore.Location.MessageListSidebar

  deactivate: ->
    ComponentRegistry.unregister('SidebarFullContact')

  serialize: -> @state

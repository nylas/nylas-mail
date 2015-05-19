_ = require 'underscore'
React = require "react"
SidebarFullContact = require "./sidebar-fullcontact"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register SidebarFullContact,
      location: WorkspaceStore.Location.MessageListSidebar

  deactivate: ->
    ComponentRegistry.unregister(SidebarFullContact)

  serialize: -> @state

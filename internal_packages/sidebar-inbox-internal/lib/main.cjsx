_ = require 'underscore-plus'
React = require "react"
SidebarInternal = require "./sidebar-internal"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register SidebarInternal,
      location: WorkspaceStore.Location.MessageListSidebar

  deactivate: ->
    ComponentRegistry.unregister(SidebarInternal)

  serialize: -> @state

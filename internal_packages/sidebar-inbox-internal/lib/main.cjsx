_ = require 'underscore-plus'
React = require "react"
SidebarInternal = require "./sidebar-internal"
{ComponentRegistry, WorkspaceStore} = require "inbox-exports"

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register
      name: 'SidebarInternal'
      view: SidebarInternal
      location: WorkspaceStore.Location.MessageListSidebar

  deactivate: ->
    ComponentRegistry.unregister('SidebarInternal')

  serialize: -> @state

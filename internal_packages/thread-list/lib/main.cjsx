_ = require 'underscore'
React = require "react"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

{DownButton, UpButton, ThreadBulkArchiveButton, ThreadBulkStarButton} = require "./thread-buttons"
ThreadSelectionBar = require './thread-selection-bar'
ThreadList = require './thread-list'

DraftSelectionBar = require './draft-selection-bar'
DraftList = require './draft-list'

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register ThreadList,
      location: WorkspaceStore.Location.ThreadList

    ComponentRegistry.register ThreadSelectionBar,
      location: WorkspaceStore.Location.ThreadList.Toolbar

    ComponentRegistry.register DraftList,
      location: WorkspaceStore.Location.DraftList

    ComponentRegistry.register DraftSelectionBar,
      location: WorkspaceStore.Location.DraftList.Toolbar

    ComponentRegistry.register DownButton,
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right
      modes: ['list']

    ComponentRegistry.register UpButton,
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right
      modes: ['list']

    ComponentRegistry.register ThreadBulkArchiveButton,
      role: 'thread:BulkAction'

    ComponentRegistry.register ThreadBulkStarButton,
      role: 'thread:BulkAction'

  deactivate: ->
    ComponentRegistry.unregister DraftList
    ComponentRegistry.unregister DraftSelectionBar
    ComponentRegistry.unregister ThreadList
    ComponentRegistry.unregister ThreadSelectionBar
    ComponentRegistry.unregister ThreadBulkArchiveButton
    ComponentRegistry.unregister DownButton
    ComponentRegistry.unregister UpButton

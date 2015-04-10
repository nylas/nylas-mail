_ = require 'underscore-plus'
React = require "react"
{ComponentRegistry, WorkspaceStore} = require "inbox-exports"

{DownButton, UpButton, ThreadBulkArchiveButton} = require "./thread-buttons"
ThreadSelectionBar = require './thread-selection-bar'
ThreadList = require './thread-list'

DraftSelectionBar = require './draft-selection-bar'
DraftList = require './draft-list'

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register
      view: ThreadList
      name: 'ThreadList'
      location: WorkspaceStore.Location.ThreadList

    ComponentRegistry.register
      name: 'ThreadSelectionBar'
      view: ThreadSelectionBar
      location: WorkspaceStore.Location.ThreadList.Toolbar

    ComponentRegistry.register
      view: DraftList
      name: 'DraftList'
      location: WorkspaceStore.Location.DraftList

    ComponentRegistry.register
      name: 'DraftSelectionBar'
      view: DraftSelectionBar
      location: WorkspaceStore.Location.DraftList.Toolbar

    ComponentRegistry.register
      name: 'DownButton'
      mode: 'list'
      view: DownButton
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right

    ComponentRegistry.register
      name: 'UpButton'
      mode: 'list'
      view: UpButton
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right

    ComponentRegistry.register
      view: ThreadBulkArchiveButton
      name: 'ThreadBulkArchiveButton'
      role: 'thread:BulkAction'

  deactivate: ->
    ComponentRegistry.unregister 'DraftList'
    ComponentRegistry.unregister 'DraftSelectionBar'
    ComponentRegistry.unregister 'ThreadList'
    ComponentRegistry.unregister 'ThreadSelectionBar'
    ComponentRegistry.unregister 'ThreadBulkArchiveButton'
    ComponentRegistry.unregister 'DownButton'
    ComponentRegistry.unregister 'UpButton'

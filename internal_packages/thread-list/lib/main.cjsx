_ = require 'underscore'
React = require "react"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

{DownButton, UpButton, ThreadBulkArchiveButton, ThreadBulkTrashButton,
 ThreadBulkStarButton, ThreadBulkToggleUnreadButton} = require "./thread-buttons"
{DraftDeleteButton} = require "./draft-buttons"
ThreadSelectionBar = require './thread-selection-bar'
ThreadList = require './thread-list'

DraftListSidebarItem = require './draft-list-sidebar-item'
DraftSelectionBar = require './draft-selection-bar'
DraftList = require './draft-list'

module.exports =
  activate: (@state={}) ->
    WorkspaceStore.defineSheet 'Drafts', {root: true},
      list: ['RootSidebar', 'DraftList']

    @sidebarItem = new WorkspaceStore.SidebarItem
      component: DraftListSidebarItem
      sheet: WorkspaceStore.Sheet.Drafts
      id: 'Drafts'
      name: 'Drafts'

    WorkspaceStore.addSidebarItem(@sidebarItem)

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

    ComponentRegistry.register ThreadBulkTrashButton,
      role: 'thread:BulkAction'

    ComponentRegistry.register ThreadBulkStarButton,
      role: 'thread:BulkAction'

    ComponentRegistry.register ThreadBulkToggleUnreadButton,
      role: 'thread:BulkAction'

    ComponentRegistry.register DraftDeleteButton,
      role: 'draft:BulkAction'

  deactivate: ->
    ComponentRegistry.unregister DraftList
    ComponentRegistry.unregister DraftSelectionBar
    ComponentRegistry.unregister ThreadList
    ComponentRegistry.unregister ThreadSelectionBar
    ComponentRegistry.unregister ThreadBulkArchiveButton
    ComponentRegistry.unregister ThreadBulkTrashButton
    ComponentRegistry.unregister ThreadBulkToggleUnreadButton
    ComponentRegistry.unregister DownButton
    ComponentRegistry.unregister UpButton
    ComponentRegistry.unregister DraftDeleteButton

_ = require 'underscore'
React = require "react"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

ThreadList = require './thread-list'
ThreadListToolbar = require './thread-list-toolbar'
MessageListToolbar = require './message-list-toolbar'
SelectedItemsStack = require './selected-items-stack'

{UpButton,
 DownButton,
 TrashButton,
 ArchiveButton,
 MarkAsSpamButton,
 ToggleUnreadButton,
 ToggleStarredButton} = require "./thread-toolbar-buttons"

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register ThreadList,
      location: WorkspaceStore.Location.ThreadList

    ComponentRegistry.register SelectedItemsStack,
      location: WorkspaceStore.Location.MessageList
      modes: ['split']

    # Toolbars
    ComponentRegistry.register ThreadListToolbar,
      location: WorkspaceStore.Location.ThreadList.Toolbar
      modes: ['list']

    ComponentRegistry.register MessageListToolbar,
      location: WorkspaceStore.Location.MessageList.Toolbar

    ComponentRegistry.register DownButton,
      location: WorkspaceStore.Location.MessageList.Toolbar
      modes: ['list']

    ComponentRegistry.register UpButton,
      location: WorkspaceStore.Location.MessageList.Toolbar
      modes: ['list']

    ComponentRegistry.register ArchiveButton,
      role: 'ThreadActionsToolbarButton'

    ComponentRegistry.register TrashButton,
      role: 'ThreadActionsToolbarButton'

    ComponentRegistry.register MarkAsSpamButton,
      role: 'ThreadActionsToolbarButton'

    ComponentRegistry.register ToggleStarredButton,
      role: 'ThreadActionsToolbarButton'

    ComponentRegistry.register ToggleUnreadButton,
      role: 'ThreadActionsToolbarButton'

  deactivate: ->
    ComponentRegistry.unregister ThreadList
    ComponentRegistry.unregister SelectedItemsStack
    ComponentRegistry.unregister ThreadListToolbar
    ComponentRegistry.unregister MessageListToolbar
    ComponentRegistry.unregister ArchiveButton
    ComponentRegistry.unregister TrashButton
    ComponentRegistry.unregister MarkAsSpamButton
    ComponentRegistry.unregister ToggleUnreadButton
    ComponentRegistry.unregister ToggleStarredButton
    ComponentRegistry.unregister UpButton
    ComponentRegistry.unregister DownButton

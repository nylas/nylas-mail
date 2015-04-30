FileFrame = require "./file-frame"
FileList = require './file-list'
FileSelectionBar = require './file-selection-bar'
{ComponentRegistry,
 WorkspaceStore} = require 'inbox-exports'

module.exports =

  activate: (@state={}) ->
    WorkspaceStore.defineSheet 'Files', {root: true, supportedModes: ['list'], name: 'Files'},
      list: ['RootSidebar', 'FileList']

    WorkspaceStore.defineSheet 'File', {supportedModes: ['list']},
      list: ['File']

    ComponentRegistry.register FileList,
      location: WorkspaceStore.Location.FileList

    ComponentRegistry.register FileSelectionBar,
      location: WorkspaceStore.Location.FileList.Toolbar

    ComponentRegistry.register FileFrame,
      location: WorkspaceStore.Location.File

  deactivate: ->
    ComponentRegistry.unregister FileList
    ComponentRegistry.unregister FileSelectionBar
    ComponentRegistry.unregister FileFrame

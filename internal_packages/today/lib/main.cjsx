TodayView = require "./today-view"
TodayIcon = require "./today-icon"
{ComponentRegistry,
 WorkspaceStore} = require 'nylas-exports'

module.exports =

  activate: (@state={}) ->
    WorkspaceStore.defineSheet 'Today', {root: true, supportedModes: ['list'], name: 'Today', icon: TodayIcon},
      list: ['RootSidebar', 'Today']

    ComponentRegistry.register TodayView,
      location: WorkspaceStore.Location.Today

  deactivate: ->
    ComponentRegistry.unregister(TodayView)
    WorkspaceStore.undefineSheet('Today')
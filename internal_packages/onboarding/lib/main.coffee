PageRouter = require "./page-router"
{SystemStartService, WorkspaceStore, ComponentRegistry} = require 'nylas-exports'

module.exports =
  item: null

  activate: (@state) ->
    # This package does nothing in other windows
    return unless NylasEnv.getWindowType() is 'onboarding'

    WorkspaceStore.defineSheet 'Main', {root: true},
      list: ['Center']

    ComponentRegistry.register PageRouter,
      location: WorkspaceStore.Location.Center

    startService = new SystemStartService()
    if (NylasEnv.config.get('nylas.accounts')?.length ? 0) is 0
      startService.checkAvailability().then (available) =>
        startService.doesLaunchOnSystemStart().then (launchOnStart) =>
          startService.configureToLaunchOnSystemStart() unless launchOnStart

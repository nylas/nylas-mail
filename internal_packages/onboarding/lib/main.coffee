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

    if (NylasEnv.config.get('nylas.accounts')?.length ? 0) is 0
      startService = new SystemStartService()
      startService.checkAvailability().then (available) =>
        return unless available
        startService.doesLaunchOnSystemStart().then (launchesOnStart) =>
          startService.configureToLaunchOnSystemStart() unless launchesOnStart

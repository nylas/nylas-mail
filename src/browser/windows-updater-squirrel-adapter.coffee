{EventEmitter} = require 'events'
_ = require 'underscore'
WindowsUpdater = require './windows-updater'

class WindowsUpdaterSquirrelAdapter
  _.extend @prototype, EventEmitter.prototype

  setFeedURL: (@updateUrl) ->

  restartN1: ->
    if WindowsUpdater.existsSync()
      WindowsUpdater.restartN1(require('app'))
    else
      NylasEnv.reportError(new Error("SquirrellUpdate does not exist"))

  downloadUpdate: (callback) ->
    WindowsUpdater.spawn ['--download', @updateUrl], (error, stdout) ->
      return callback(error) if error?

      try
        # Last line of output is the JSON details about the releases
        json = stdout.trim().split('\n').pop()
        update = JSON.parse(json)?.releasesToApply?.pop?()
      catch error
        error.stdout = stdout
        return callback(error)

      callback(null, update)

  installUpdate: (callback) ->
    WindowsUpdater.spawn(['--update', @updateUrl], callback)

  supportsUpdates: ->
    WindowsUpdater.existsSync()

  downloadAndInstallUpdate: ->
    throw new Error('Update URL is not set') unless @updateUrl

    @emit 'checking-for-update'

    unless WindowsUpdater.existsSync()
      @emit 'update-not-available'
      return

    @downloadUpdate (error, update) =>
      if error?
        @emit 'update-not-available'
        return

      unless update?
        @emit 'update-not-available'
        return

      @emit 'update-available'
      @installUpdate (error) =>
        if error?
          @emit 'error', error
          return

        # During this time, Windows Squirrel will invoke the Nylas.exe
        # with a variety of flags as event hooks.
        #
        # See https://github.com/Squirrel/Squirrel.Windows/blob/master/docs/using/custom-squirrel-events-non-cs.md
        #
        # See `handleStartupEventsWithSquirrel` in `src/browser/main.js`

        @emit 'update-downloaded', {}, update.releaseNotes, update.version

module.exports = new WindowsUpdaterSquirrelAdapter()

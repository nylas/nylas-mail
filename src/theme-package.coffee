Q = require 'q'
Package = require './package'

module.exports =
class ThemePackage extends Package
  getType: -> 'theme'

  getStyleSheetPriority: -> 1

  enable: ->
    NylasEnv.config.unshiftAtKeyPath('core.themes', @name)

  disable: ->
    NylasEnv.config.removeAtKeyPath('core.themes', @name)

  load: ->
    @measure 'loadTime', =>
      try
        @metadata ?= Package.loadMetadata(@path)
      catch error
        console.warn "Failed to load theme named '#{@name}'", error.stack ? error
    this

  activate: ->
    return @activationDeferred.promise if @activationDeferred?

    @activationDeferred = Q.defer()
    @measure 'activateTime', =>
      @loadStylesheets()
      @activateNow()

    @activationDeferred.promise

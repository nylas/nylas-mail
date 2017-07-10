Package = require './package'

module.exports =
class ThemePackage extends Package
  getType: -> 'theme'

  getStyleSheetPriority: -> 1

  enable: ->
    NylasEnv.themes.setActiveTheme(@name)

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
    unless @isActivated
      @measure 'activateTime', =>
        @loadStylesheets()
        @activateNow()
      @isActivated = true
    return Promise.resolve()

_ = require 'underscore'
path = require 'path'

class SoundRegistry
  constructor: ->
    @_sounds = {}

  playSound: (name) ->
    return if NylasEnv.inSpecMode()
    src = @_sounds[name]
    return unless src

    a = new Audio()

    if _.isString src
      if src.indexOf("nylas://") is 0
        a.src = src
      else
        a.src = path.join(resourcePath, 'static', 'sounds', src)
    else if _.isArray src
      {resourcePath} = NylasEnv.getLoadSettings()
      args = [resourcePath].concat(src)
      a.src = path.join.apply(@, args)

    a.autoplay = true
    a.play()

  register: (name, path) ->
    if _.isObject(name)
      @_sounds[key] = path for key, path of name
    else if _.isString(name)
      @_sounds[name] = path

  unregister: (name) ->
    if _.isArray(name)
      delete @_sounds[key] for key in name
    else if _.isString(name)
      delete @_sounds[name]

module.exports = new SoundRegistry()

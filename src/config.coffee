_ = require 'underscore'
_ = _.extend(_, require('./config-utils'))
{remote} = require 'electron'
fs = require 'fs-plus'
EmitterMixin = require('emissary').Emitter
{CompositeDisposable, Disposable, Emitter} = require 'event-kit'

Color = require './color'

if process.type is 'renderer'
  app = remote.getGlobal('application')
  webContentsId = remote.getCurrentWebContents().getId()
else
  app = global.application
  webContentsId = null

# Essential: Used to access all of N1's configuration details.
#
# An instance of this class is always available as the `NylasEnv.config` global.
#
# ## Getting and setting config settings.
#
# ```coffee
# # Note that with no value set, ::get returns the setting's default value.
# NylasEnv.config.get('my-package.myKey') # -> 'defaultValue'
#
# NylasEnv.config.set('my-package.myKey', 'value')
# NylasEnv.config.get('my-package.myKey') # -> 'value'
# ```
#
# You may want to watch for changes. Use {::observe} to catch changes to the setting.
#
# ```coffee
# NylasEnv.config.set('my-package.myKey', 'value')
# NylasEnv.config.observe 'my-package.myKey', (newValue) ->
#   # `observe` calls immediately and every time the value is changed
#   console.log 'My configuration changed:', newValue
# ```
#
# If you want a notification only when the value changes, use {::onDidChange}.
#
# ```coffee
# NylasEnv.config.onDidChange 'my-package.myKey', ({newValue, oldValue}) ->
#   console.log 'My configuration changed:', newValue, oldValue
# ```
#
# ### Value Coercion
#
# Config settings each have a type specified by way of a
# [schema](json-schema.org). For example we might an integer setting that only
# allows integers greater than `0`:
#
# ```coffee
# # When no value has been set, `::get` returns the setting's default value
# NylasEnv.config.get('my-package.anInt') # -> 12
#
# # The string will be coerced to the integer 123
# NylasEnv.config.set('my-package.anInt', '123')
# NylasEnv.config.get('my-package.anInt') # -> 123
#
# # The string will be coerced to an integer, but it must be greater than 0, so is set to 1
# NylasEnv.config.set('my-package.anInt', '-20')
# NylasEnv.config.get('my-package.anInt') # -> 1
# ```
#
# ## Defining settings for your package
#
# Define a schema under a `config` key in your package main.
#
# ```coffee
# module.exports =
#   # Your config schema
#   config:
#     someInt:
#       type: 'integer'
#       default: 23
#       minimum: 1
#
#   activate: (state) -> # ...
#   # ...
# ```
#
# ## Config Schemas
#
# We use [json schema](http://json-schema.org) which allows you to define your value's
# default, the type it should be, etc. A simple example:
#
# ```coffee
# # We want to provide an `enableThing`, and a `thingVolume`
# config:
#   enableThing:
#     type: 'boolean'
#     default: false
#   thingVolume:
#     type: 'integer'
#     default: 5
#     minimum: 1
#     maximum: 11
# ```
#
# The type keyword allows for type coercion and validation. If a `thingVolume` is
# set to a string `'10'`, it will be coerced into an integer.
#
# ```coffee
# NylasEnv.config.set('my-package.thingVolume', '10')
# NylasEnv.config.get('my-package.thingVolume') # -> 10
#
# # It respects the min / max
# NylasEnv.config.set('my-package.thingVolume', '400')
# NylasEnv.config.get('my-package.thingVolume') # -> 11
#
# # If it cannot be coerced, the value will not be set
# NylasEnv.config.set('my-package.thingVolume', 'cats')
# NylasEnv.config.get('my-package.thingVolume') # -> 11
# ```
#
# ### Supported Types
#
# The `type` keyword can be a string with any one of the following. You can also
# chain them by specifying multiple in an an array. For example
#
# ```coffee
# config:
#   someSetting:
#     type: ['boolean', 'integer']
#     default: 5
#
# # Then
# NylasEnv.config.set('my-package.someSetting', 'true')
# NylasEnv.config.get('my-package.someSetting') # -> true
#
# NylasEnv.config.set('my-package.someSetting', '12')
# NylasEnv.config.get('my-package.someSetting') # -> 12
# ```
#
# #### string
#
# Values must be a string.
#
# ```coffee
# config:
#   someSetting:
#     type: 'string'
#     default: 'hello'
# ```
#
# #### integer
#
# Values will be coerced into integer. Supports the (optional) `minimum` and
# `maximum` keys.
#
#   ```coffee
#   config:
#     someSetting:
#       type: 'integer'
#       default: 5
#       minimum: 1
#       maximum: 11
#   ```
#
# #### number
#
# Values will be coerced into a number, including real numbers. Supports the
# (optional) `minimum` and `maximum` keys.
#
# ```coffee
# config:
#   someSetting:
#     type: 'number'
#     default: 5.3
#     minimum: 1.5
#     maximum: 11.5
# ```
#
# #### boolean
#
# Values will be coerced into a Boolean. `'true'` and `'false'` will be coerced into
# a boolean. Numbers, arrays, objects, and anything else will not be coerced.
#
# ```coffee
# config:
#   someSetting:
#     type: 'boolean'
#     default: false
# ```
#
# #### array
#
# Value must be an Array. The types of the values can be specified by a
# subschema in the `items` key.
#
# ```coffee
# config:
#   someSetting:
#     type: 'array'
#     default: [1, 2, 3]
#     items:
#       type: 'integer'
#       minimum: 1.5
#       maximum: 11.5
# ```
#
# #### object
#
# Value must be an object. This allows you to nest config options. Sub options
# must be under a `properties key`
#
# ```coffee
# config:
#   someSetting:
#     type: 'object'
#     properties:
#       myChildIntOption:
#         type: 'integer'
#         minimum: 1.5
#         maximum: 11.5
# ```
#
# #### color
#
# Values will be coerced into a {Color} with `red`, `green`, `blue`, and `alpha`
# properties that all have numeric values. `red`, `green`, `blue` will be in
# the range 0 to 255 and `value` will be in the range 0 to 1. Values can be any
# valid CSS color format such as `#abc`, `#abcdef`, `white`,
# `rgb(50, 100, 150)`, and `rgba(25, 75, 125, .75)`.
#
# ```coffee
# config:
#   someSetting:
#     type: 'color'
#     default: 'white'
# ```
#
# ### Other Supported Keys
#
# #### enum
#
# All types support an `enum` key. The enum key lets you specify all values
# that the config setting can possibly be. `enum` _must_ be an array of values
# of your specified type. Schema:
#
# ```coffee
# config:
#   someSetting:
#     type: 'integer'
#     default: 4
#     enum: [2, 4, 6, 8]
# ```
#
# Usage:
#
# ```coffee
# NylasEnv.config.set('my-package.someSetting', '2')
# NylasEnv.config.get('my-package.someSetting') # -> 2
#
# # will not set values outside of the enum values
# NylasEnv.config.set('my-package.someSetting', '3')
# NylasEnv.config.get('my-package.someSetting') # -> 2
#
# # If it cannot be coerced, the value will not be set
# NylasEnv.config.set('my-package.someSetting', '4')
# NylasEnv.config.get('my-package.someSetting') # -> 4
# ```
#
# #### title and description
#
# The settings view will use the `title` and `description` keys to display your
# config setting in a readable way. By default the settings view humanizes your
# config key, so `someSetting` becomes `Some Setting`. In some cases, this is
# confusing for users, and a more descriptive title is useful.
#
# Descriptions will be displayed below the title in the settings view.
#
# ```coffee
# config:
#   someSetting:
#     title: 'Setting Magnitude'
#     description: 'This will affect the blah and the other blah'
#     type: 'integer'
#     default: 4
# ```
#
# __Note__: You should strive to be so clear in your naming of the setting that
# you do not need to specify a title or description!
#
# ## Best practices
#
# * Don't depend on (or write to) configuration keys outside of your keypath.
#
module.exports =
class Config
  EmitterMixin.includeInto(this)
  @schemaEnforcers = {}

  @addSchemaEnforcer: (typeName, enforcerFunction) ->
    @schemaEnforcers[typeName] ?= []
    @schemaEnforcers[typeName].push(enforcerFunction)

  @addSchemaEnforcers: (filters) ->
    for typeName, functions of filters
      for name, enforcerFunction of functions
        @addSchemaEnforcer(typeName, enforcerFunction)

  @executeSchemaEnforcers: (keyPath, value, schema) ->
    error = null
    types = schema.type
    types = [types] unless Array.isArray(types)
    for type in types
      try
        enforcerFunctions = @schemaEnforcers[type].concat(@schemaEnforcers['*'])
        for enforcer in enforcerFunctions
          # At some point in one's life, one must call upon an enforcer.
          value = enforcer.call(this, keyPath, value, schema)
        error = null
        break
      catch e
        error = e

    throw error if error?
    value

  # Created during initialization, available as `NylasEnv.config`
  constructor: ->
    # `app` exists in the remote browser process. We do this to use a
    # single DB connection for the Config
    @configPersistenceManager = app.configPersistenceManager
    @emitter = new Emitter
    @schema =
      type: 'object'
      properties: {}

    @settings = {}
    @defaultSettings = {}
    @transactDepth = 0

    if process.type is 'renderer'
      {ipcRenderer} = require 'electron'
      # If new Config() has already been called, unmount it's listener when
      # we attach ourselves. This is only done during specs, Config is a singleton.
      ipcRenderer.removeAllListeners('on-config-reloaded')
      ipcRenderer.on 'on-config-reloaded', (event, settings) =>
        @updateSettings(settings)

  load: ->
    @updateSettings(@getRawValues())

  ###
  Section: Config Subscription
  ###

  # Essential: Add a listener for changes to a given key path. This is different
  # than {::onDidChange} in that it will immediately call your callback with the
  # current value of the config entry.
  #
  # ### Examples
  #
  # You might want to be notified when the themes change. We'll watch
  # `core.themes` for changes
  #
  # ```coffee
  # NylasEnv.config.observe 'core.themes', (value) ->
  #   # do stuff with value
  # ```
  #
  # * `keyPath` {String} name of the key to observe
  # * `callback` {Function} to call when the value of the key changes.
  #   * `value` the new value of the key
  #
  # Returns a {Disposable} with the following keys on which you can call
  # `.dispose()` to unsubscribe.
  observe: (keyPath, callback) ->
    callback(@get(keyPath))
    @onDidChangeKeyPath keyPath, (event) -> callback(event.newValue)

  # Essential: Add a listener for changes to a given key path. If `keyPath` is
  # not specified, your callback will be called on changes to any key.
  #
  # * `keyPath` (optional) {String} name of the key to observe.
  # * `callback` {Function} to call when the value of the key changes.
  #   * `event` {Object}
  #     * `newValue` the new value of the key
  #     * `oldValue` the prior value of the key.
  #     * `keyPath` the keyPath of the changed key
  #
  # Returns a {Disposable} with the following keys on which you can call
  # `.dispose()` to unsubscribe.
  onDidChange: ->
    if arguments.length is 1
      [callback] = arguments
    else if arguments.length is 2
      [keyPath, callback] = arguments
    @onDidChangeKeyPath(keyPath, callback)

  ###
  Section: Managing Settings
  ###

  # Essential: Retrieves the setting for the given key.
  #
  # ### Examples
  #
  # You might want to know what themes are enabled, so check `core.themes`
  #
  # ```coffee
  # NylasEnv.config.get('core.themes')
  # ```
  #
  # * `keyPath` The {String} name of the key to retrieve.
  #
  # Returns the value from N1's default settings, the user's configuration
  # file in the type specified by the configuration schema.
  get: (keyPath) ->
    @getRawValue(keyPath)

  # Essential: Sets the value for a configuration setting.
  #
  # This value is stored in N1's internal configuration file.
  #
  # ### Examples
  #
  # You might want to change the themes programmatically:
  #
  # ```coffee
  # NylasEnv.config.set('core.themes', ['ui-light', 'my-custom-theme'])
  # ```
  #
  # * `keyPath` The {String} name of the key.
  # * `value` The value of the setting. Passing `undefined` will revert the
  #   setting to the default value.
  #
  # Returns a {Boolean}
  # * `true` if the value was set.
  # * `false` if the value was not able to be coerced to the type specified in the setting's schema.
  set: (keyPath, value) ->
    unless value is undefined
      try
        value = @makeValueConformToSchema(keyPath, value)
      catch e
        return false

    defaultValue = _.valueForKeyPath(this.defaultSettings, keyPath)
    if (_.isEqual(defaultValue, value))
      value = undefined

    # Ensure that we never send anything but plain javascript objects through remote.
    if _.isObject(value)
      value = JSON.parse(JSON.stringify(value))

    @setRawValue(keyPath, value)
    true

  # Essential: Restore the setting at `keyPath` to its default value.
  #
  # * `keyPath` The {String} name of the key.
  # * `options` (optional) {Object}
  unset: (keyPath) ->
    @set(keyPath, _.valueForKeyPath(@defaultSettings, keyPath))

  # Extended: Retrieve the schema for a specific key path. The schema will tell
  # you what type the keyPath expects, and other metadata about the config
  # option.
  #
  # * `keyPath` The {String} name of the key.
  #
  # Returns an {Object} eg. `{type: 'integer', default: 23, minimum: 1}`.
  # Returns `null` when the keyPath has no schema specified.
  getSchema: (keyPath) ->
    keys = splitKeyPath(keyPath)
    schema = @schema
    for key in keys
      break unless schema?
      schema = schema.properties?[key]
    schema

  # Extended: Suppress calls to handler functions registered with {::onDidChange}
  # and {::observe} for the duration of `callback`. After `callback` executes,
  # handlers will be called once if the value for their key-path has changed.
  #
  # * `callback` {Function} to execute while suppressing calls to handlers.
  transact: (callback) ->
    @transactDepth++
    try
      callback()
    finally
      @transactDepth--
      @emitChangeEvent()

  ###
  Section: Internal methods used by core
  ###

  pushAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    unless arrayValue instanceof Array
      throw new Error("Config.pushAtKeyPath is intended for array values. Value #{JSON.stringify(arrayValue)} is not an array.")
    result = arrayValue.push(value)
    @set(keyPath, arrayValue)
    result

  unshiftAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    unless arrayValue instanceof Array
      throw new Error("Config.unshiftAtKeyPath is intended for array values. Value #{JSON.stringify(arrayValue)} is not an array.")
    result = arrayValue.unshift(value)
    @set(keyPath, arrayValue)
    result

  removeAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    unless arrayValue instanceof Array
      throw new Error("Config.removeAtKeyPath is intended for array values. Value #{JSON.stringify(arrayValue)} is not an array.")
    result = _.remove(arrayValue, value)
    @set(keyPath, arrayValue)
    result

  setSchema: (keyPath, schema) ->
    unless isPlainObject(schema)
      throw new Error("Error loading schema for #{keyPath}: schemas can only be objects!")

    unless typeof schema.type?
      throw new Error("Error loading schema for #{keyPath}: schema objects must have a type attribute")

    rootSchema = @schema
    if keyPath
      for key in splitKeyPath(keyPath)
        rootSchema.type = 'object'
        rootSchema.properties ?= {}
        properties = rootSchema.properties
        properties[key] ?= {}
        rootSchema = properties[key]

    _.extend rootSchema, schema
    @setDefaults(keyPath, @extractDefaultsFromSchema(schema))
    @resetSettingsForSchemaChange()

  ###
  Section: Private methods managing global settings
  ###

  updateSettings: (newSettings) =>
    @settings = newSettings || {}
    @emitChangeEvent()

  getRawValue: (keyPath) ->
    value = _.valueForKeyPath(@settings, keyPath)
    defaultValue = _.valueForKeyPath(@defaultSettings, keyPath)

    if value?
      value = @deepClone(value)
      _.defaults(value, defaultValue) if isPlainObject(value) and isPlainObject(defaultValue)
    else
      value = @deepClone(defaultValue)

    value

  onDidChangeKeyPath: (keyPath, callback) ->
    oldValue = @get(keyPath)
    @emitter.on 'did-change', =>
      newValue = @get(keyPath)
      unless _.isEqual(oldValue, newValue)
        event = {oldValue, newValue}
        oldValue = newValue
        callback(event)

  isSubKeyPath: (keyPath, subKeyPath) ->
    return false unless keyPath? and subKeyPath?
    pathSubTokens = splitKeyPath(subKeyPath)
    pathTokens = splitKeyPath(keyPath).slice(0, pathSubTokens.length)
    _.isEqual(pathTokens, pathSubTokens)

  setRawDefault: (keyPath, value) ->
    _.setValueForKeyPath(@defaultSettings, keyPath, value)
    @emitChangeEvent()

  setDefaults: (keyPath, defaults) ->
    if defaults? and isPlainObject(defaults)
      keys = splitKeyPath(keyPath)
      for key, childValue of defaults
        continue unless defaults.hasOwnProperty(key)
        @setDefaults(keys.concat([key]).join('.'), childValue)
    else
      try
        defaults = @makeValueConformToSchema(keyPath, defaults)
        @setRawDefault(keyPath, defaults)
      catch e
        console.warn("'#{keyPath}' could not set the default. Attempted default: #{JSON.stringify(defaults)}; Schema: #{JSON.stringify(@getSchema(keyPath))}")

  deepClone: (object) ->
    if object instanceof Color
      object.clone()
    else if _.isArray(object)
      object.map (value) => @deepClone(value)
    else if isPlainObject(object)
      _.mapObject object, (value) => @deepClone(value)
    else
      object

  extractDefaultsFromSchema: (schema) ->
    if schema.default?
      schema.default
    else if schema.type is 'object' and schema.properties? and isPlainObject(schema.properties)
      defaults = {}
      properties = schema.properties or {}
      defaults[key] = @extractDefaultsFromSchema(value) for key, value of properties
      defaults

  makeValueConformToSchema: (keyPath, value, options) ->
    if options?.suppressException
      try
        @makeValueConformToSchema(keyPath, value)
      catch e
        undefined
    else
      value = @constructor.executeSchemaEnforcers(keyPath, value, schema) if schema = @getSchema(keyPath)
      value

  # When the schema is changed / added, there may be values set in the config
  # that do not conform to the schema. This will reset make them conform.
  resetSettingsForSchemaChange: ->
    @transact =>
      settings = @getRawValues()
      settings = @makeValueConformToSchema(null, settings, suppressException: true)
      @configPersistenceManager.resetConfig(settings)
      @load()
      return

  emitChangeEvent: ->
    @emitter.emit 'did-change' unless @transactDepth > 0

  getRawValues: ->
    return @configPersistenceManager.getRawValues()

  setRawValue: (keyPath, value) ->
    @configPersistenceManager.setRawValue(keyPath, value, webContentsId)
    @load()

# Base schema enforcers. These will coerce raw input into the specified type,
# and will throw an error when the value cannot be coerced. Throwing the error
# will indicate that the value should not be set.
#
# Enforcers are run from most specific to least. For a schema with type
# `integer`, all the enforcers for the `integer` type will be run first, in
# order of specification. Then the `*` enforcers will be run, in order of
# specification.
Config.addSchemaEnforcers
  'integer':
    coerce: (keyPath, value, schema) ->
      value = parseInt(value)
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} cannot be coerced into an int") if isNaN(value) or not isFinite(value)
      value

  'number':
    coerce: (keyPath, value, schema) ->
      value = parseFloat(value)
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} cannot be coerced into a number") if isNaN(value) or not isFinite(value)
      value

  'boolean':
    coerce: (keyPath, value, schema) ->
      switch typeof value
        when 'string'
          if value.toLowerCase() is 'true'
            true
          else if value.toLowerCase() is 'false'
            false
          else
            throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be a boolean or the string 'true' or 'false'")
        when 'boolean'
          value
        else
          throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be a boolean or the string 'true' or 'false'")

  'string':
    validate: (keyPath, value, schema) ->
      unless typeof value is 'string'
        throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be a string")
      value

  'null':
    # null sort of isnt supported. It will just unset in this case
    coerce: (keyPath, value, schema) ->
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be null") unless value in [undefined, null]
      value

  'object':
    coerce: (keyPath, value, schema) ->
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be an object") unless isPlainObject(value)
      return value unless schema.properties?

      newValue = {}
      for prop, propValue of value
        childSchema = schema.properties[prop]
        if childSchema?
          try
            newValue[prop] = @executeSchemaEnforcers("#{keyPath}.#{prop}", propValue, childSchema)
          catch error
            console.warn "Error setting item in object: #{error.message}"
        else
          # Just pass through un-schema'd values
          newValue[prop] = propValue

      newValue

  'array':
    coerce: (keyPath, value, schema) ->
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be an array") unless Array.isArray(value)
      itemSchema = schema.items
      if itemSchema?
        newValue = []
        for item in value
          try
            newValue.push @executeSchemaEnforcers(keyPath, item, itemSchema)
          catch error
            console.warn "Error setting item in array: #{error.message}"
        newValue
      else
        value

  'color':
    coerce: (keyPath, value, schema) ->
      color = Color.parse(value)
      unless color?
        throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} cannot be coerced into a color")
      color

  '*':
    coerceMinimumAndMaximum: (keyPath, value, schema) ->
      return value unless typeof value is 'number'
      if schema.minimum? and typeof schema.minimum is 'number'
        value = Math.max(value, schema.minimum)
      if schema.maximum? and typeof schema.maximum is 'number'
        value = Math.min(value, schema.maximum)
      value

    validateEnum: (keyPath, value, schema) ->
      possibleValues = schema.enum
      return value unless possibleValues? and Array.isArray(possibleValues) and possibleValues.length

      for possibleValue in possibleValues
        # Using `isEqual` for possibility of placing enums on array and object schemas
        return value if _.isEqual(possibleValue, value)

      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} is not one of #{JSON.stringify(possibleValues)}")

isPlainObject = (value) ->
  _.isObject(value) and not _.isArray(value) and not _.isFunction(value) and not _.isString(value) and not (value instanceof Color)

splitKeyPath = (keyPath) ->
  return [] unless keyPath?
  startIndex = 0
  keyPathArray = []
  for char, i in keyPath
    if char is '.' and (i is 0 or keyPath[i-1] != '\\')
      keyPathArray.push keyPath.substring(startIndex, i)
      startIndex = i + 1
  keyPathArray.push keyPath.substr(startIndex, keyPath.length)
  keyPathArray

withoutEmptyObjects = (object) ->
  resultObject = undefined
  if isPlainObject(object)
    for key, value of object
      newValue = withoutEmptyObjects(value)
      if newValue?
        resultObject ?= {}
        resultObject[key] = newValue
  else
    resultObject = object
  resultObject

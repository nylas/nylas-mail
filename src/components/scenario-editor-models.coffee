_ = require 'underscore'

class Comparator
  constructor: (@name, @fn) ->

  evaluate: ({actual, desired}) ->
    if actual instanceof Array
      _.any actual, (actual) => @fn({actual, desired})
    else
      @fn({actual, desired})

Comparator.Default = new Comparator 'Default', ({actual, desired}) ->
  _.isEqual(actual, desired)

class Template
  @Type:
    None: 'None'
    Enum: 'Enum'
    String: 'String'

  @Comparator: Comparator
  @Comparators:
    String:
      contains: new Comparator 'contains', ({actual, desired}) ->
        return false unless actual and desired
        actual.toLowerCase().indexOf(desired.toLowerCase()) isnt -1

      doesNotContain: new Comparator 'does not contain', ({actual, desired}) ->
        return false unless actual and desired
        actual.toLowerCase().indexOf(desired.toLowerCase()) is -1

      beginsWith: new Comparator 'begins with', ({actual, desired}) ->
        return false unless actual and desired
        actual.toLowerCase().indexOf(desired.toLowerCase()) is 0

      endsWith: new Comparator 'ends with', ({actual, desired}) ->
        return false unless actual and desired
        actual.toLowerCase().lastIndexOf(desired.toLowerCase()) is actual.length - desired.length

      equals: new Comparator 'equals', ({actual, desired}) ->
        actual is desired

      matchesExpression: new Comparator 'matches expression', ({actual, desired}) ->
        return false unless actual and desired
        new RegExp(desired, "gi").test(actual)


  constructor: (@key, @type, options = {}) ->
    defaults =
      name: @key
      values: undefined
      valueLabel: undefined
      comparators: @constructor.Comparators[@type] || {}

    _.extend(@, defaults, options)

    unless @key
      throw new Error("You must provide a valid key.")
    unless @type in _.values(@constructor.Type)
      throw new Error("You must provide a valid type.")
    if @type is @constructor.Type.Enum and not @values
      throw new Error("You must provide `values` when creating an enum.")

    @

  createDefaultInstance: ->
    templateKey: @key,
    comparatorKey: Object.keys(@comparators)[0]
    value: undefined

  coerceInstance: (instance) ->
    instance.templateKey = @key
    if not @comparators
      instance.comparatorKey = undefined
    else if not (instance.comparatorKey in Object.keys(@comparators))
      instance.comparatorKey = Object.keys(@comparators)[0]
    instance

  evaluate: (instance, value) ->
    comparator = @comparators[instance.comparatorKey]
    comparator ?= Comparator.Default
    comparator.evaluate(actual: value, desired: instance.value)

module.exports = {Template, Comparator}

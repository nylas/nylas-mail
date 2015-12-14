_ = require 'underscore'

class DeprecateUtils
  @warn: (condition, message) ->
    console.warn message if condition

  @deprecate: (fnName, newName, ctx, fn) ->
    if NylasEnv.inDevMode() and not NylasEnv.inSpecMode()
      warn = true
      newFn = =>
        DeprecateUtils.warn(
          warn,
          "Deprecation warning! #{fnName} is deprecated and will be removed soon.
          Use #{newName} instead."
        )
        warn = false
        return fn.apply(ctx, arguments)
      return _.extend(newFn, fn)
    return fn

module.exports = DeprecateUtils

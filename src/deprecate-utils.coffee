_ = require 'underscore'

class DeprecateUtils
  # See
  # http://www.codeovertones.com/2011/08/how-to-print-stack-trace-anywhere-in.html
  @parseStack: (stackString) ->
    stack = stackString
      .replace(/^[^\(]+?[\n$]/gm, '')
      .replace(/^\s+at\s+/gm, '')
      .replace(/^Object.<anonymous>\s*\(/gm, '{anonymous}()@')
      .split('\n')
    return stack

  @warn: (condition, message) ->
    console.warn message if condition

  @deprecate: (fnName, newName, ctx, fn) ->
    if NylasEnv.inDevMode() and not NylasEnv.inSpecMode()
      warn = true
      newFn = =>
        stack = DeprecateUtils.parseStack((new Error()).stack)
        DeprecateUtils.warn(
          warn,
          "Deprecation warning! #{fnName} is deprecated and will be removed soon.
          Use #{newName} instead.\nCheck your code at #{stack[1]}"
        )
        warn = false
        return fn.apply(ctx, arguments)
      return _.extend(newFn, fn)
    return fn

module.exports = DeprecateUtils

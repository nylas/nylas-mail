# This file contains custom Inbox error classes.
#
# In general I think these should be created as sparingly as possible.
# Only add one if you really can't use native `new Error("my msg")`


# A wrapper around the three arguments we get back from node's `request`
# method. We wrap it in an error object because Promises can only call
# `reject` or `resolve` with one argument (not three).
class APIError extends Error
  constructor: ({@error, @response, @body, @requestOptions, @statusCode} = {}) ->
    @statusCode ?= @response?.statusCode
    @name = "APIError"
    @message = @body?.message ? @body ? @error?.toString?()

  notifyConsole: ->
    console.error("Edgehill API Error: #{@message}", @)

module.exports =
  "APIError": APIError

_ = require 'underscore'
inflection = require 'inflection'
Thread = require '../models/thread'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
ChangeMailTask = require './change-mail-task'

class ChangeUnreadTask extends ChangeMailTask
  constructor: ({@unread}={}) ->
    super

  description: ->
    count = @threads.length
    type = 'thread'
    type = inflection.pluralize(type) if count > 1

    if @_isUndoTask
      return "Undoing changes to #{count} #{type}"

    newState = if @unread is true then "unread" else "read"
    if count > 1
      return "Marked #{count} #{type} as #{newState}"
    else
      return "Marked as #{newState}"

  performLocal: ->
    if @threads.length is 0
      return Promise.reject(new Error("ChangeUnreadTask: You must provide a `threads` Array of models or IDs."))

    # Convert arrays of IDs or models to models.
    # modelify returns immediately if no work is required
    Promise.props(
      threads: DatabaseStore.modelify(Thread, @threads)
    ).then ({folder, threads, messages}) =>
      @threads = _.compact(threads)
      return super

  _processesNestedMessages: ->
    true

  _changesToModel: (model) ->
    {unread: @unread}

  _requestBodyForModel: (model) ->
    unread: model.unread

module.exports = ChangeUnreadTask

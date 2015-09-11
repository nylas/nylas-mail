_ = require 'underscore'
inflection = require 'inflection'
Thread = require '../models/thread'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
ChangeMailTask = require './change-mail-task'

class ChangeStarredTask extends ChangeMailTask
  constructor: ({@starred}={}) ->
    super

  label: ->
    if @starred
      "Starring…"
    else
      "Unstarring…"

  description: ->
    count = @threads.length
    type = 'thread'
    type = inflection.pluralize(type) if count > 1

    if @_isUndoTask
      return "Undoing changes to #{count} #{type}"

    verb = if @starred is true then "Starred" else "Unstarred"
    if count > 1
      return "#{verb} #{count} #{type}"
    else
      return "#{verb}"

  performLocal: ->
    if @threads.length is 0
      return Promise.reject(new Error("ChangeStarredTask: You must provide a `threads` Array of models or IDs."))

    # Convert arrays of IDs or models to models.
    # modelify returns immediately if no work is required
    Promise.props(
      threads: DatabaseStore.modelify(Thread, @threads)
    ).then ({folder, threads, messages}) =>
      @threads = _.compact(threads)
      return super

  _changesToModel: (model) ->
    {starred: @starred}

  _requestBodyForModel: (model) ->
    starred: model.starred

module.exports = ChangeStarredTask

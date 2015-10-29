_ = require 'underscore'
Task = require './task'
Label = require '../models/label'
Thread = require '../models/thread'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
ChangeMailTask = require './change-mail-task'
SyncbackCategoryTask = require './syncback-category-task'

# Public: Create a new task to apply labels to a message or thread.
#
# Takes an options object of the form:
# - labelsToAdd: An {Array} of {Label}s or {Label} ids to add
# - labelsToRemove: An {Array} of {Label}s or {Label} ids to remove
# - threads: An {Array} of {Thread}s or {Thread} ids
# - messages: An {Array} of {Message}s or {Message} ids
class ChangeLabelsTask extends ChangeMailTask

  constructor: ({@labelsToAdd, @labelsToRemove}={}) ->
    @labelsToAdd ?= []
    @labelsToRemove ?= []
    super

  label: -> "Applying labels…"

  description: ->
    type = "thread"
    if @threads.length > 1
      type = "threads"
    if @labelsToAdd.length is 1 and @labelsToRemove.length is 0 and @labelsToAdd[0] instanceof Label
      return "Added #{@labelsToAdd[0].displayName} to #{@threads.length} #{type}"
    if @labelsToAdd.length is 0 and @labelsToRemove.length is 1 and @labelsToRemove[0] instanceof Label
      return "Removed #{@labelsToRemove[0].displayName} from #{@threads.length} #{type}"
    return "Changed labels on #{@threads.length} #{type}"

  isDependentTask: (other) -> other instanceof SyncbackCategoryTask

  performLocal: ->
    if @labelsToAdd.length is 0 and @labelsToRemove.length is 0
      return Promise.reject(new Error("ChangeLabelsTask: Must specify `labelsToAdd` or `labelsToRemove`"))
    if @threads.length > 0 and @messages.length > 0
      return Promise.reject(new Error("ChangeLabelsTask: You can move `threads` or `messages` but not both"))
    if @threads.length is 0 and @messages.length is 0
      return Promise.reject(new Error("ChangeLabelsTask: You must provide a `threads` or `messages` Array of models or IDs."))

    # Convert arrays of IDs or models to models.
    # modelify returns immediately if no work is required
    Promise.props(
      labelsToAdd: DatabaseStore.modelify(Label, @labelsToAdd)
      labelsToRemove: DatabaseStore.modelify(Label, @labelsToRemove)
      threads: DatabaseStore.modelify(Thread, @threads)
      messages: DatabaseStore.modelify(Message, @messages)

    ).then ({labelsToAdd, labelsToRemove, threads, messages}) =>
      # Remove any objects we weren't able to find. This can happen pretty easily
      # if you undo an action and other things have happened.
      @labelsToAdd = _.compact(labelsToAdd)
      @labelsToRemove = _.compact(labelsToRemove)
      @threads = _.compact(threads)
      @messages = _.compact(messages)

      # The base class does the heavy lifting and calls changesToModel
      return super

  processNestedMessages: ->
    false

  changesToModel: (model) ->
    labelsToRemoveIds = _.pluck(@labelsToRemove, 'id')

    labels = [].concat(model.labels, @labelsToAdd)
    labels = _.reject labels, (label) -> label.id in labelsToRemoveIds
    labels = _.uniq labels, false, (label) -> label.id
    {labels}

  requestBodyForModel: (model) ->
    labels: model.labels.map (l) -> l.id

module.exports = ChangeLabelsTask

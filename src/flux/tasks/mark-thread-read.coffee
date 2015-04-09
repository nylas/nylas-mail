Task = require './task'
DatabaseStore = require '../stores/database-store'
AddRemoveTagsTask = require './add-remove-tags'
Message = require '../models/message'
Thread = require '../models/thread'
Actions = require '../actions'
_ = require 'underscore-plus'

# A subclass of AddRemoveTagsTask that adds a bit of additional behavior.
# It optimistically sets unread=false on the messages in a thread when the
# thread is marked as read.
class MarkThreadReadTask extends AddRemoveTagsTask

  constructor: (@thread) ->
    super(@thread, [], ['unread'])
    @

  performLocal: ->
    if not @thread or not @thread instanceof Thread
      return Promise.reject(new Error("Attempt to call AddRemoveTagsTask.performLocal without Thread"))

    # Do standard add/remove tag to remove unread tag
    markThread = super
    markMessages = new Promise (resolve, reject) =>
      # mark all of the messages in the thread as read locally. When this
      # tag change is executed on the server, all of the messages in the thread
      # will be marked as read. It looks bad to temporarily have unread messages
      # in a read thread...
      DatabaseStore.findAll(Message, threadId: @thread.id).then (messages) ->
        messages = _.filter messages, (message) -> message.unread
        if messages.length > 0
          for message in messages
            message.unread = false
          DatabaseStore.persistModels(messages).then(resolve)
        else
          resolve()

    Promise.all([markThread, markMessages])

  performRemote: ->
    super

module.exports = MarkThreadReadTask

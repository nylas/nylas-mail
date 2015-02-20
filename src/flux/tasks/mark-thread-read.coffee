Task = require './task'
DatabaseStore = require '../stores/database-store'
AddRemoveTagsTask = require './add-remove-tags'
Message = require '../models/message'
Actions = require '../actions'
_ = require 'underscore-plus'

# A subclass of AddRemoveTagsTask that adds a bit of additional behavior.
# It optimistically sets unread=false on the messages in a thread when the
# thread is marked as read.
class MarkThreadReadTask extends AddRemoveTagsTask

  constructor: (@threadId) ->
    super(@threadId, [], ['unread'])
    @

  performLocal: ->
    # Do standard add/remove tag to remove unread tag
    super.then =>
      new Promise (resolve, reject) =>
        # mark all of the messages in the thread as read locally. When this
        # tag change is executed on the server, all of the messages in the thread
        # will be marked as read. It looks bad to temporarily have unread messages
        # in a read thread...
        DatabaseStore.findAll(Message, threadId: @threadId).then (messages) ->
          messages = _.filter messages, (message) -> message.unread
          if messages.length > 0
            for message in messages
              message.unread = false
            DatabaseStore.persistModels(messages).then(resolve)
          else
            resolve()

  performRemote: ->
    super

module.exports = MarkThreadReadTask

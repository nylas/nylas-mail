{isTempId} = require '../models/utils'

Actions = require '../actions'
DatabaseStore = require '../stores/database-store'
Message = require '../models/message'
Task = require './task'
SaveDraftTask = require './save-draft'

class SendDraftTask extends Task

  constructor: (@draftLocalId) -> @

  shouldCancelUnstartedTask: (other) ->
    other instanceof SendDraftTask and other.draftLocalId is @draftLocalId

  shouldWaitForTask: (other) ->
    other instanceof SaveDraftTask and other.draftLocalId is @draftLocalId

  performLocal: ->
    # When we send drafts, we don't update anything in the app until
    # it actually succeeds. We don't want users to think messages have
    # already sent when they haven't!
    return Promise.reject("Attempt to call SendDraftTask.performLocal without @draftLocalId") unless @draftLocalId
    Actions.postNotification({message: "Sending message…", type: 'info'})
    Promise.resolve()

  performRemote: ->
    new Promise (resolve, reject) =>
      # Fetch the latest draft data to make sure we make the request with the most
      # recent draft version
      DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) ->
        # The draft may have been deleted by another task. Nothing we can do.
        return resolve() unless draft
        return reject(new Error("Cannot send draft that is not saved!")) unless draft.isSaved()

        atom.inbox.makeRequest
          path: "/n/#{draft.namespaceId}/send"
          method: 'POST'
          body:
            draft_id: draft.id
            version: draft.version
          returnsModel: true
          success: ->
            Actions.postNotification({message: "Sent!", type: 'success'})
            DatabaseStore.unpersistModel(draft).then(resolve)
          error: reject

module.exports = SendDraftTask

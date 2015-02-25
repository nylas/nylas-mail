_ = require 'underscore-plus'
moment = require 'moment'

Reflux = require 'reflux'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'

SaveDraftTask = require '../tasks/save-draft'
SendDraftTask = require '../tasks/send-draft'
DestroyDraftTask = require '../tasks/destroy-draft'

Thread = require '../models/thread'
Message = require '../models/message'
Actions = require '../actions'

# A DraftStore responds to Actions that interact with Drafts and exposes
# public getter methods to return Draft objects.
#
# It also handles the dispatching of Tasks to persist changes to the Inbox
# API.
#
# Remember that a "Draft" is actually just a "Message" with draft: true.
#
module.exports =
DraftStore = Reflux.createStore
  init: ->
    @listenTo DatabaseStore, @_onDataChanged

    @listenTo Actions.composeReply, @_onComposeReply
    @listenTo Actions.composeForward, @_onComposeForward
    @listenTo Actions.composeReplyAll, @_onComposeReplyAll
    @listenTo Actions.composePopoutDraft, @_onComposePopoutDraft
    @listenTo Actions.composeNewBlankDraft, @_onComposeNewBlankDraft

    @listenTo Actions.saveDraft, @_onSaveDraft
    @listenTo Actions.sendDraft, @_onSendDraft
    @listenTo Actions.destroyDraft, @_onDestroyDraft

    @listenTo Actions.removeFile, @_onRemoveFile
    @listenTo Actions.persistUploadedFile, @_onFileUploaded

  ######### PUBLIC #######################################################

  # Returns a promise
  findByLocalId: (localId) ->
    DatabaseStore.findByLocalId(Message, localId)

  ########### PRIVATE ####################################################

  _onDataChanged: (change) ->
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft
    @trigger(change)

  _onComposeReply: (context) ->
    @_newMessageWithContext context, (thread, message) ->
      replyToMessageId: message.id
      quotedMessage: message
      to: message.from

  _onComposeReplyAll: (context) ->
    @_newMessageWithContext context, (thread, message) ->
      replyToMessageId: message.id
      quotedMessage: message
      to: message.from
      cc: [].concat(message.cc, message.to).filter (p) ->
        !_.contains([].concat(message.from, [NamespaceStore.current().me()]), p)

  _onComposeForward: (context) ->
    @_newMessageWithContext context, (thread, message) ->
      subject: "Fwd: " + thread.subject
      quotedMessage: message

  _newMessageWithContext: ({threadId, messageId}, attributesCallback) ->
    queries = {}
    queries.thread = DatabaseStore.find(Thread, threadId)
    if messageId?
      queries.message = DatabaseStore.find(Message, messageId)
    else
      queries.message = DatabaseStore.findBy(Message, {threadId: threadId}).order(Message.attributes.date.descending()).limit(1)

    # Waits for the query promises to resolve and then resolve with a hash
    # of their resolved values. *swoon*
    Promise.props(queries).then ({thread, message}) ->
      attributes = attributesCallback(thread, message)
      attributes.subject ?= thread.subject

      if attributes.quotedMessage
        contact = attributes.quotedMessage.from[0] ? new Contact(name: 'Unknown', email:'Unknown')
        quoteDate = moment(attributes.quotedMessage.date).format("MMM D YYYY, [at] h:mm a")

        if contact.name
          quoteAttribution = "On #{quoteDate}, #{contact.name} <#{contact.email}> wrote:"
        else
          quoteAttribution = "On #{quoteDate}, #{contact.email} wrote:"

        attributes.body = """
          <br><br>
          <blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            #{quoteAttribution}
            <br>
            #{attributes.quotedMessage.body}
          </blockquote>"""
        delete attributes.quotedMessage

      draft = new Message _.extend {}, attributes,
        from: [NamespaceStore.current().me()]
        date: (new Date)
        draft: true
        threadId: thread.id
        namespaceId: thread.namespaceId

      DatabaseStore.persistModel(draft)

  # The logic to create a new Draft used to be in the DraftStore (which is
  # where it should be). It got moved to composer/lib/main.cjsx becaues
  # of an obscure atom-shell/Chrome bug whereby database requests firing right
  # before the new-window loaded would cause the new-window to load with
  # about:blank instead of its contents. By moving the DB logic there, we can
  # get around this.
  _onComposeNewBlankDraft: ->
    atom.displayComposer()

  _onComposePopoutDraft: (draftLocalId) ->
    atom.displayComposer(draftLocalId)

  _onDestroyDraft: (draftLocalId) ->
    Actions.queueTask(new DestroyDraftTask(draftLocalId))
    atom.close() if atom.state.mode is "composer"

  _onSaveDraft: (paramsWithLocalId) ->
    params = _.clone(paramsWithLocalId)
    draftLocalId = params.localId

    if (not draftLocalId?) then throw new Error("Must call saveDraft with a localId")
    delete params.localId

    if _.size(params) > 0
      task = new SaveDraftTask(draftLocalId, params)
      Actions.queueTask(task)

  _onSendDraft: (draftLocalId) ->
    Actions.queueTask(new SendDraftTask(draftLocalId))
    atom.close() if atom.state.mode is "composer"

  _findDraft: (draftLocalId) ->
    new Promise (resolve, reject) ->
      DatabaseStore.findByLocalId(Message, draftLocalId)
      .then (draft) ->
        if not draft? then reject("Can't find draft with id #{draftLocalId}")
        else resolve(draft)
      .catch (error) -> reject(error)

  # Receives:
  #   file: - A `File` object
  #   uploadData:
  #     messageLocalId
  #     filePath
  #     fileSize
  #     fileName
  #     bytesUploaded
  #     state - one of "started" "progress" "completed" "aborted" "failed"
  _onFileUploaded: ({file, uploadData}) ->
    @_findDraft(uploadData.messageLocalId)
    .then (draft) ->
      draft.files ?= []
      draft.files.push(file)
      DatabaseStore.persistModel(draft)
      Actions.queueTask(new SaveDraftTask(uploadData.messageLocalId))
    .catch (error) -> console.error(error, error.stack)

  _onRemoveFile: ({file, messageLocalId}) ->
    @_findDraft(messageLocalId)
    .then (draft) ->
      draft.files ?= []
      draft.files = _.reject draft.files, (f) -> f.id is file.id
      DatabaseStore.persistModel(draft)
      Actions.queueTask(new SaveDraftTask(uploadData.messageLocalId))
    .catch (error) -> console.error(error, error.stack)

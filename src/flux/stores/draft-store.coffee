_ = require 'underscore-plus'

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
    @listenTo Actions.fileUploaded, @_onFileUploaded

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

  _onComposeReply: (threadId) ->
    @_findLastMessageFromThread(threadId)
    .then ({lastMessage, thread}) =>
      @_createNewDraftFromThread thread,
        to: lastMessage.from

  _onComposeReplyAll: (threadId) ->
    @_findLastMessageFromThread(threadId)
    .then ({lastMessage, thread}) =>
      cc = [].concat(lastMessage.cc, lastMessage.to).filter (p) ->
        !_.contains([].concat(lastMessage.from, [NamespaceStore.current().me()]), p)
      @_createNewDraftFromThread thread,
        to: lastMessage.from
        cc: cc

  _onComposeForward: (threadId) ->
    @_findLastMessageFromThread(threadId)
    .then ({lastMessage, thread}) =>
      @_createNewDraftFromThread thread,
        subject: "Fwd: " + thread.subject
        body: lastMessage.body

  _findLastMessageFromThread: (threadId) ->
    new Promise (resolve, reject) ->
      DatabaseStore.find(Thread, threadId).then (thread) ->
        DatabaseStore.findAll(Message, threadId: threadId).then (msgs) ->
          lastMessage = msgs[0]
          if lastMessage? and thread?
            resolve({lastMessage: lastMessage, thread: thread})
          else
            console.error("A last message couldn't be found for this thread", threadId)
            reject(threadId)
        .catch (args...) -> reject(args...)
      .catch (args...) -> reject(args...)

  _createNewDraftFromThread: (thread, attributes={}) ->
    draft = new Message _.extend {}, attributes,
      from: [NamespaceStore.current().me()]
      date: (new Date)
      draft: true
      subject: thread.subject
      threadId: thread.id
      namespaceId: thread.namespaceId

    DatabaseStore.persistModel(draft)

  # The logic to create a new Draft used to be in the DraftStore (which is
  # where it should be). It got moved to inbox-composer/lib/main.cjsx becaues
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

  _onSendDraft: (draftLocalId, options = {}) ->
    DatabaseStore.findByLocalId(Message, draftLocalId).then (draft) =>
      return unless draft
      remote = require('remote')
      dialog = remote.require('dialog')

      if [].concat(draft.to, draft.cc, draft.bcc).length is 0
        dialog.showMessageBox(remote.getCurrentWindow(), {
          type: 'warning',
          buttons: ['Edit Message'],
          message: 'Cannot Send',
          detail: 'You need to provide one or more recipients before sending the message.'
        })
        return

      warnings = []
      if draft.subject.length is 0
        warnings.push('without a subject line')
      if draft.body.toLowerCase().indexOf('attachment') != -1 and draft.files?.length is 0
        warnings.push('without an attachment')

      if warnings.length > 0 and not options.force
        dialog.showMessageBox remote.getCurrentWindow(), {
          type: 'warning',
          buttons: ['Cancel', 'Send Anyway'],
          message: 'Are you sure?',
          detail: "Send #{warnings.join(' and ')}?"
        }, (response) =>
          if response is 1 # button array index 1
            @_onSendDraft(draftLocalId, {force: true})
        return

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

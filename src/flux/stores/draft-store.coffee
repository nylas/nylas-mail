_ = require 'underscore'

{ipcRenderer} = require 'electron'

NylasAPI = require '../nylas-api'
DraftStoreProxy = require './draft-store-proxy'
DraftFactory = require './draft-factory'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
TaskQueueStatusStore = require './task-queue-status-store'
FocusedContentStore = require './focused-content-store'

BaseDraftTask = require '../tasks/base-draft-task'
SendDraftTask = require '../tasks/send-draft-task'
SyncbackDraftFilesTask = require '../tasks/syncback-draft-files-task'
SyncbackDraftTask = require '../tasks/syncback-draft-task'
DestroyDraftTask = require '../tasks/destroy-draft-task'

Thread = require '../models/thread'
Contact = require '../models/contact'
Message = require '../models/message'
Actions = require '../actions'

TaskQueue = require './task-queue'
SoundRegistry = require '../../sound-registry'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

ExtensionRegistry = require '../../extension-registry'
{deprecate} = require '../../deprecate-utils'

###
Public: DraftStore responds to Actions that interact with Drafts and exposes
public getter methods to return Draft objects and sessions.

It also creates and queues {Task} objects to persist changes to the Nylas
API.

Remember that a "Draft" is actually just a "Message" with `draft: true`.

Section: Drafts
###
class DraftStore
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @listenTo DatabaseStore, @_onDataChanged

    @listenTo Actions.composeReply, @_onComposeReply
    @listenTo Actions.composeForward, @_onComposeForward
    @listenTo Actions.sendDraftSuccess, => @trigger()
    @listenTo Actions.composePopoutDraft, @_onPopoutDraftClientId
    @listenTo Actions.composeNewBlankDraft, @_onPopoutBlankDraft
    @listenTo Actions.draftSendingFailed, @_onDraftSendingFailed
    @listenTo Actions.sendQuickReply, @_onSendQuickReply

    if NylasEnv.isMainWindow()
      ipcRenderer.on 'new-message', => @_onPopoutBlankDraft()

    # Remember that these two actions only fire in the current window and
    # are picked up by the instance of the DraftStore in the current
    # window.
    @listenTo Actions.ensureDraftSynced, @_onEnsureDraftSynced
    @listenTo Actions.sendDraft, @_onSendDraft
    @listenTo Actions.destroyDraft, @_onDestroyDraft

    @listenTo Actions.removeFile, @_onRemoveFile

    NylasEnv.onBeforeUnload @_onBeforeUnload

    @_draftSessions = {}

    # We would ideally like to be able to calculate the sending state
    # declaratively from the existence of the SendDraftTask on the
    # TaskQueue.
    #
    # Unfortunately it takes a while for the Task to end up on the Queue.
    # Before it's there, the Draft session is fetched, changes are
    # applied, it's saved to the DB, and performLocal is run. In the
    # meantime, several triggers from the DraftStore may fire (like when
    # it's saved to the DB). At the time of those triggers, the task is
    # not yet on the Queue and the DraftStore incorrectly says
    # `isSendingDraft` is false.
    #
    # As a result, we keep track of the intermediate time between when we
    # request to queue something, and when it appears on the queue.
    @_draftsSending = {}

    ipcRenderer.on 'mailto', @_onHandleMailtoLink
    ipcRenderer.on 'mailfiles', @_onHandleMailFiles

  ######### PUBLIC #######################################################

  # Public: Fetch a {DraftStoreProxy} for displaying and/or editing the
  # draft with `clientId`.
  #
  # Example:
  #
  # ```coffee
  # session = DraftStore.sessionForClientId(clientId)
  # session.prepare().then ->
  #    # session.draft() is now ready
  # ```
  #
  # - `clientId` The {String} clientId of the draft.
  #
  # Returns a {Promise} that resolves to an {DraftStoreProxy} for the
  # draft once it has been prepared:
  sessionForClientId: (clientId) =>
    if not clientId
      throw new Error("DraftStore::sessionForClientId requires a clientId")
    @_draftSessions[clientId] ?= @_createSession(clientId)
    @_draftSessions[clientId].prepare()

  # Public: Look up the sending state of the given draftClientId.
  # In popout windows the existance of the window is the sending state.
  isSendingDraft: (draftClientId) ->
    return @_draftsSending[draftClientId] ? false

  ###
  Composer Extensions
  ###

  # Public: Returns the extensions registered with the DraftStore.
  extensions: =>
    ExtensionRegistry.Composer.extensions()

  # Public: Deprecated, use {ExtensionRegistry.Composer.register} instead.
  # Registers a new extension with the DraftStore. DraftStore extensions
  # make it possible to extend the editor experience, modify draft contents,
  # display warnings before draft are sent, and more.
  #
  # - `ext` A {ComposerExtension} instance.
  #
  registerExtension: (ext) =>
    ExtensionRegistry.Composer.register(ext)

  # Public: Deprecated, use {ExtensionRegistry.Composer.unregister} instead.
  # Unregisters the extension provided from the DraftStore.
  #
  # - `ext` A {ComposerExtension} instance.
  #
  unregisterExtension: (ext) =>
    ExtensionRegistry.Composer.unregister(ext)

  ########### PRIVATE ####################################################

  _doneWithSession: (session) ->
    session.teardown()
    delete @_draftSessions[session.draftClientId]

  _cleanupAllSessions: ->
    for draftClientId, session of @_draftSessions
      @_doneWithSession(session)

  _onBeforeUnload: (readyToUnload) =>
    promises = []

    # Normally we'd just append all promises, even the ones already
    # fulfilled (nothing to save), but in this case we only want to
    # block window closing if we have to do real work. Calling
    # window.close() within on onbeforeunload could do weird things.
    for key, session of @_draftSessions
      if session.draft()?.pristine
        Actions.queueTask(new DestroyDraftTask(session.draftClientId))
      else
        promises.push(session.changes.commit())

    if promises.length > 0
      # Important: There are some scenarios where all the promises resolve instantly.
      # Firing NylasEnv.close() does nothing if called within an existing beforeUnload
      # handler, so we need to always defer by one tick before re-firing close.
      Promise.settle(promises).then =>
        @_draftSessions = {}
        readyToUnload()

      # Stop and wait before closing
      return false
    else
      # Continue closing
      return true

  _onDataChanged: (change) =>
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft
    @trigger(change)

  _onSendQuickReply: ({thread, threadId, message, messageId}, body) =>
    Promise.props(@_modelifyContext({thread, threadId, message, messageId}))
    .then ({message, thread}) =>
      DraftFactory.createDraftForReply({message, thread, type: 'reply'})
    .then (draft) =>
      draft.body = body + "\n\n" + draft.body
      draft.pristine = false
      DatabaseStore.inTransaction (t) =>
        t.persistModel(draft)
      .then =>
        Actions.sendDraft(draft.clientId)

  _onComposeReply: ({thread, threadId, message, messageId, popout, type, behavior}) =>
    Promise.props(@_modelifyContext({thread, threadId, message, messageId}))
    .then ({message, thread}) =>
      DraftFactory.createOrUpdateDraftForReply({message, thread, type, behavior})
    .then (draft) =>
      @_finalizeAndPersistNewMessage(draft, {popout})

  _onComposeForward: ({thread, threadId, message, messageId, popout}) =>
    Promise.props(@_modelifyContext({thread, threadId, message, messageId}))
    .then(DraftFactory.createDraftForForward)
    .then (draft) =>
      @_finalizeAndPersistNewMessage(draft, {popout})

  _modelifyContext: ({thread, threadId, message, messageId}) ->
    queries = {}
    if thread
      throw new Error("newMessageWithContext: `thread` present, expected a Model. Maybe you wanted to pass `threadId`?") unless thread instanceof Thread
      queries.thread = thread
    else
      queries.thread = DatabaseStore.find(Thread, threadId)

    if message
      throw new Error("newMessageWithContext: `message` present, expected a Model. Maybe you wanted to pass `messageId`?") unless message instanceof Message
      queries.message = message
    else if messageId?
      queries.message = DatabaseStore
        .find(Message, messageId)
        .include(Message.attributes.body)
    else
      queries.message = DatabaseStore
        .findBy(Message, {threadId: threadId ? thread.id})
        .order(Message.attributes.date.descending())
        .limit(1)
        .include(Message.attributes.body)

    queries

  _finalizeAndPersistNewMessage: (draft, {popout} = {}) =>
    # Give extensions an opportunity to perform additional setup to the draft
    for extension in @extensions()
      continue unless extension.prepareNewDraft
      extension.prepareNewDraft({draft})

    # Optimistically create a draft session and hand it the draft so that it
    # doesn't need to do a query for it a second from now when the composer wants it.
    @_createSession(draft.clientId, draft)

    DatabaseStore.inTransaction (t) =>
      t.persistModel(draft)
    .then =>
      if popout
        @_onPopoutDraftClientId(draft.clientId)
      else
        Actions.focusDraft({draftClientId: draft.clientId})
    .thenReturn({draftClientId: draft.clientId, draft: draft})

  _createSession: (clientId, draft) =>
    @_draftSessions[clientId] = new DraftStoreProxy(clientId, draft)

  _onPopoutBlankDraft: =>
    DraftFactory.createDraft().then (draft) =>
      @_finalizeAndPersistNewMessage(draft).then ({draftClientId}) =>
        @_onPopoutDraftClientId(draftClientId, {newDraft: true})

  _onPopoutDraftClientId: (draftClientId, options = {}) =>
    if not draftClientId?
      throw new Error("DraftStore::onPopoutDraftId - You must provide a draftClientId")

    draftJSON = null
    save = Promise.resolve()
    if @_draftSessions[draftClientId]
      save = @_draftSessions[draftClientId].changes.commit()
      draftJSON = @_draftSessions[draftClientId].draft().toJSON()

    title = if options.newDraft then "New Message" else "Message"

    save.then =>
      app = require('electron').remote.getGlobal('application')
      existing = app.windowManager.windowWithPropsMatching({draftClientId})
      if existing
        existing.restore() if existing.isMinimized()
        existing.focus()
      else
        NylasEnv.newWindow
          title: title
          windowType: "composer"
          windowProps: _.extend(options, {draftClientId, draftJSON})

  _onHandleMailtoLink: (event, urlString) =>
    DraftFactory.createDraftForMailto(urlString).then (draft) =>
      @_finalizeAndPersistNewMessage(draft, popout: true)

  _onHandleMailFiles: (event, paths) =>
    DraftFactory.createDraft().then (draft) =>
      @_finalizeAndPersistNewMessage(draft, popout: true)
    .then ({draftClientId}) =>
      for path in paths
        Actions.addAttachment({filePath: path, messageClientId: draftClientId})

  _onDestroyDraft: (draftClientId) =>
    session = @_draftSessions[draftClientId]

    # Immediately reset any pending changes so no saves occur
    if session
      @_doneWithSession(session)

    # Stop any pending tasks related ot the draft
    for task in TaskQueueStatusStore.queue()
      if task instanceof BaseDraftTask and task.draftClientId is draftClientId
        Actions.dequeueTask(task.id)

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftClientId))

    NylasEnv.close() if @_isPopout()

  _onEnsureDraftSynced: (draftClientId) =>
    @sessionForClientId(draftClientId).then (session) =>
      @_prepareForSyncback(session).then =>
        if session.draft().files.length or session.draft().uploads.length
          Actions.queueTask(new SyncbackDraftFilesTask(draftClientId))
        Actions.queueTask(new SyncbackDraftTask(draftClientId))

  _onSendDraft: (draftClientId) =>
    @_draftsSending[draftClientId] = true

    @sessionForClientId(draftClientId).then (session) =>
      @_prepareForSyncback(session).then =>
        if NylasEnv.config.get("core.sending.sounds")
          SoundRegistry.playSound('hit-send')
        if session.draft().files.length or session.draft().uploads.length
          Actions.queueTask(new SyncbackDraftFilesTask(draftClientId))
        Actions.queueTask(new SendDraftTask(draftClientId))
        @_doneWithSession(session)

        if @_isPopout()
          NylasEnv.close()

  _isPopout: ->
    NylasEnv.getWindowType() is "composer"

  _prepareForSyncback: (session) =>
    draft = session.draft()

    # Make sure the draft is attached to a valid account, and change it's
    # accountId if the from address does not match the current account.
    account = AccountStore.accountForEmail(draft.from[0].email)
    unless account
      return Promise.reject(new Error("DraftStore::_prepareForSyncback - you can only send drafts from a configured account."))

    if account.id isnt draft.accountId
      NylasAPI.makeDraftDeletionRequest(draft)
      session.changes.add({
        accountId: account.id
        version: null
        serverId: null
        threadId: null
        replyToMessageId: null
      })

    # Run draft transformations registered by third-party plugins
    allowedFields = ['to', 'from', 'cc', 'bcc', 'subject', 'body']

    Promise.each @extensions(), (ext) ->
      extApply = ext.applyTransformsToDraft
      extUnapply = ext.unapplyTransformsToDraft
      unless extApply and extUnapply
        return Promise.resolve()

      draft = session.draft().clone()
      Promise.resolve(extUnapply({draft})).then (cleaned) =>
        cleaned = draft if cleaned is 'unnecessary'
        Promise.resolve(extApply({draft: cleaned})).then (transformed) =>
          Promise.resolve(extUnapply({draft: transformed.clone()})).then (untransformed) =>
            untransformed = cleaned if untransformed is 'unnecessary'

            if not _.isEqual(_.pick(untransformed, allowedFields), _.pick(cleaned, allowedFields))
              console.log("-- BEFORE --")
              console.log(draft.body)
              console.log("-- TRANSFORMED --")
              console.log(transformed.body)
              console.log("-- UNTRANSFORMED (should match BEFORE) --")
              console.log(untransformed.body)
              NylasEnv.reportError(new Error("An extension applied a tranform to the draft that it could not reverse."))
            session.changes.add(_.pick(transformed, allowedFields))

    .then =>
      session.changes.commit(noSyncback: true)

  _onRemoveFile: ({file, messageClientId}) =>
    @sessionForClientId(messageClientId).then (session) ->
      files = _.clone(session.draft().files) ? []
      files = _.reject files, (f) -> f.id is file.id
      session.changes.add({files})
      session.changes.commit()

  _onDraftSendingFailed: ({draftClientId, threadId, errorMessage}) ->
    @_draftsSending[draftClientId] = false
    @trigger(draftClientId)
    if NylasEnv.isMainWindow()
      # We delay so the view has time to update the restored draft. If we
      # don't delay the modal may come up in a state where the draft looks
      # like it hasn't been restored or has been lost.
      _.delay =>
        @_notifyUserOfError({draftClientId, threadId, errorMessage})
      , 100

  _notifyUserOfError: ({draftClientId, threadId, errorMessage}) ->
    focusedThread = FocusedContentStore.focused('thread')
    if threadId and focusedThread?.id is threadId
      NylasEnv.showErrorDialog(errorMessage)
    else
      Actions.composePopoutDraft(draftClientId, {errorMessage})

# Deprecations
store = new DraftStore()
store.registerExtension = deprecate(
  'DraftStore.registerExtension',
  'ExtensionRegistry.Composer.register',
  store,
  store.registerExtension
)
store.unregisterExtension = deprecate(
  'DraftStore.unregisterExtension',
  'ExtensionRegistry.Composer.unregister',
  store,
  store.unregisterExtension
)
module.exports = store

_ = require 'underscore'
crypto = require 'crypto'
moment = require 'moment'

{ipcRenderer} = require 'electron'

DraftStoreProxy = require './draft-store-proxy'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
ContactStore = require './contact-store'
FocusedPerspectiveStore = require './focused-perspective-store'
FocusedContentStore = require './focused-content-store'

SendDraftTask = require '../tasks/send-draft'
DestroyDraftTask = require '../tasks/destroy-draft'

InlineStyleTransformer = require '../../services/inline-style-transformer'
SanitizeTransformer = require '../../services/sanitize-transformer'

Thread = require '../models/thread'
Contact = require '../models/contact'
Message = require '../models/message'
Utils = require '../models/utils'
MessageUtils = require '../models/message-utils'
Actions = require '../actions'

TaskQueue = require './task-queue'
SoundRegistry = require '../../sound-registry'

{subjectWithPrefix} = require '../models/utils'
{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'
DOMUtils = require '../../dom-utils'

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
    @listenTo Actions.composeReplyAll, @_onComposeReplyAll
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
    @_draftSessions[clientId] ?= new DraftStoreProxy(clientId)
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

  _onBeforeUnload: =>
    promises = []

    # Normally we'd just append all promises, even the ones already
    # fulfilled (nothing to save), but in this case we only want to
    # block window closing if we have to do real work. Calling
    # window.close() within on onbeforeunload could do weird things.
    for key, session of @_draftSessions
      if session.draft()?.pristine
        Actions.queueTask(new DestroyDraftTask(draftClientId: session.draftClientId))
      else
        promises.push(session.changes.commit())

    if promises.length > 0
      # Important: There are some scenarios where all the promises resolve instantly.
      # Firing NylasEnv.close() does nothing if called within an existing beforeUnload
      # handler, so we need to always defer by one tick before re-firing close.
      Promise.settle(promises).then =>
        @_draftSessions = {}
        NylasEnv.finishUnload()

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

  _onSendQuickReply: (context, body) =>
    @_newMessageWithContext context, (thread, message) =>
      {to, cc} = message.participantsForReply()
      return {
        replyToMessage: message
        to: to
      }
    .then ({draft}) =>
      draft.body = body + "\n\n" + draft.body
      draft.pristine = false
      DatabaseStore.inTransaction (t) =>
        t.persistModel(draft)
      .then =>
        Actions.sendDraft(draft.clientId)

  _onComposeReply: (context) =>
    @_newMessageWithContext context, (thread, message) =>
      {to, cc} = message.participantsForReply()
      return {
        replyToMessage: message
        to: to
      }

  _onComposeReplyAll: (context) =>
    @_newMessageWithContext context, (thread, message) =>
      {to, cc} = message.participantsForReplyAll()
      return {
        replyToMessage: message
        to: to
        cc: cc
      }

  _onComposeForward: (context) =>
    @_newMessageWithContext context, (thread, message) ->
      forwardMessage: message

  _finalizeAndPersistNewMessage: (draft) =>
    # Give extensions an opportunity to perform additional setup to the draft
    for extension in @extensions()
      continue unless extension.prepareNewDraft
      extension.prepareNewDraft({draft})

    # Optimistically create a draft session and hand it the draft so that it
    # doesn't need to do a query for it a second from now when the composer wants it.
    @_draftSessions[draft.clientId] = new DraftStoreProxy(draft.clientId, draft)

    DatabaseStore.inTransaction (t) =>
      t.persistModel(draft)
    .then =>
      Promise.resolve(draftClientId: draft.clientId, draft: draft)

  _newMessageWithContext: (args, attributesCallback) =>
    # We accept all kinds of context. You can pass actual thread and message objects,
    # or you can pass Ids and we'll look them up. Passing the object is preferable,
    # and in most cases "the data is right there" anyway. Lookups add extra latency
    # that feels bad.
    queries = @_buildModelResolvers(args)
    queries.attributesCallback = attributesCallback

    # Waits for the query promises to resolve and then resolve with a hash
    # of their resolved values. *swoon*
    Promise.props(queries)
    .then @_prepareNewMessageAttributes
    .then @_constructDraft
    .then @_finalizeAndPersistNewMessage
    .then ({draftClientId, draft}) =>
      Actions.composePopoutDraft(draftClientId) if args.popout
      Promise.resolve({draftClientId, draft})

  _buildModelResolvers: ({thread, threadId, message, messageId}) ->
    queries = {}
    if thread?
      throw new Error("newMessageWithContext: `thread` present, expected a Model. Maybe you wanted to pass `threadId`?") unless thread instanceof Thread
      queries.thread = thread
    else
      queries.thread = DatabaseStore.find(Thread, threadId)

    if message?
      throw new Error("newMessageWithContext: `message` present, expected a Model. Maybe you wanted to pass `messageId`?") unless message instanceof Message
      queries.message = message
    else if messageId?
      queries.message = DatabaseStore.find(Message, messageId)
      queries.message.include(Message.attributes.body)
    else
      queries.message = DatabaseStore.findBy(Message, {threadId: threadId ? thread.id}).order(Message.attributes.date.descending()).limit(1)
      queries.message.include(Message.attributes.body)
    return queries

  _constructDraft: ({attributes, thread}) =>
    account = AccountStore.accountForId(thread.accountId)
    throw new Error("Cannot find #{thread.accountId}") unless account
    return new Message _.extend {}, attributes,
      from: [account.me()]
      date: (new Date)
      draft: true
      pristine: true
      threadId: thread.id
      accountId: thread.accountId

  _prepareNewMessageAttributes: ({thread, message, attributesCallback}) =>
    attributes = attributesCallback(thread, message)
    attributes.subject ?= subjectWithPrefix(thread.subject, 'Re:')

    # We set the clientID here so we have a unique id to use for shipping
    # the body to the browser process.
    attributes.clientId = Utils.generateTempId()

    @_prepareAttributesBody(attributes).then (body) ->
      attributes.body = body

      if attributes.replyToMessage
        msg = attributes.replyToMessage
        attributes.subject = subjectWithPrefix(msg.subject, 'Re:')
        attributes.replyToMessageId = msg.id
        delete attributes.quotedMessage

      else if attributes.forwardMessage
        msg = attributes.forwardMessage

        if msg.files?.length > 0
          attributes.files ?= []
          attributes.files = attributes.files.concat(msg.files)

        attributes.subject = subjectWithPrefix(msg.subject, 'Fwd:')
        delete attributes.forwardedMessage

      return {attributes, thread}

  _prepareAttributesBody: (attributes) ->
    if attributes.replyToMessage
      replyToMessage = attributes.replyToMessage
      @_prepareBodyForQuoting(replyToMessage.body).then (body) ->
        return """
          <br><br><blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            #{DOMUtils.escapeHTMLCharacters(replyToMessage.replyAttributionLine())}
            <br>
            #{body}
          </blockquote>"""
    else if attributes.forwardMessage
      forwardMessage = attributes.forwardMessage
      contactsAsHtml = (cs) ->
        DOMUtils.escapeHTMLCharacters(_.invoke(cs, "toString").join(", "))
      fields = []
      fields.push("From: #{contactsAsHtml(forwardMessage.from)}") if forwardMessage.from.length > 0
      fields.push("Subject: #{forwardMessage.subject}")
      fields.push("Date: #{forwardMessage.formattedDate()}")
      fields.push("To: #{contactsAsHtml(forwardMessage.to)}") if forwardMessage.to.length > 0
      fields.push("CC: #{contactsAsHtml(forwardMessage.cc)}") if forwardMessage.cc.length > 0
      fields.push("BCC: #{contactsAsHtml(forwardMessage.bcc)}") if forwardMessage.bcc.length > 0
      @_prepareBodyForQuoting(forwardMessage.body).then (body) ->
        return """
          <br><br><blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            Begin forwarded message:
            <br><br>
            #{fields.join('<br>')}
            <br><br>
            #{body}
          </blockquote>"""
    else return Promise.resolve("")

  # Eventually we'll want a nicer solution for inline attachments
  _prepareBodyForQuoting: (body="") =>
    ## Fix inline images
    cidRE = MessageUtils.cidRegexString

    # Be sure to match over multiple lines with [\s\S]*
    # Regex explanation here: https://regex101.com/r/vO6eN2/1
    re = new RegExp("<img.*#{cidRE}[\\s\\S]*?>", "igm")
    body.replace(re, "")

    InlineStyleTransformer.run(body).then (body) =>
      SanitizeTransformer.run(body, SanitizeTransformer.Preset.UnsafeOnly)

  _onPopoutBlankDraft: =>
    # TODO Remove this when we add account selector inside composer
    account = FocusedPerspectiveStore.current().account
    account ?= AccountStore.accounts()[0]

    draft = new Message
      body: ""
      from: [account.me()]
      date: (new Date)
      draft: true
      pristine: true
      accountId: account.id

    @_finalizeAndPersistNewMessage(draft).then ({draftClientId}) =>
      @_onPopoutDraftClientId(draftClientId, {newDraft: true})

  _onPopoutDraftClientId: (draftClientId, options = {}) =>
    if not draftClientId?
      throw new Error("DraftStore::onPopoutDraftId - You must provide a draftClientId")

    save = Promise.resolve()
    if @_draftSessions[draftClientId]
      save = @_draftSessions[draftClientId].changes.commit()

    title = if options.newDraft then "New Message" else "Message"

    save.then =>
      app = require('remote').getGlobal('application')
      existing = app.windowManager.windowWithPropsMatching({draftClientId})
      if existing
        existing.restore() if existing.isMinimized()
        existing.focus()
      else
        NylasEnv.newWindow
          title: title
          windowType: "composer"
          windowProps: _.extend(options, {draftClientId})

  _onHandleMailtoLink: (event, urlString) =>
    # TODO Remove this when we add account selector inside composer
    account = FocusedPerspectiveStore.current().account
    account ?= AccountStore.accounts()[0]

    try
      urlString = decodeURI(urlString)

    [whole, to, queryString] = /mailto:\/*([^\?\&]*)((.|\n|\r)*)/.exec(urlString)

    # /many/ mailto links are malformed and do things like:
    #   &body=https://github.com/atom/electron/issues?utf8=&q=is%3Aissue+is%3Aopen+123&subject=...
    #   (note the unescaped ? and & in the URL).
    #
    # To account for these scenarios, we parse the query string manually and only
    # split on params we expect to be there. (Jumping from &body= to &subject=
    # in the above example.) We only decode values when they appear to be entirely
    # URL encoded. (In the above example, decoding the body would cause the URL
    # to fall apart.)
    #
    query = {}
    query.to = to

    querySplit = /[&|?](subject|body|cc|to|from|bcc)+\s*=/gi

    openKey = null
    openValueStart = null

    until match is null
      match = querySplit.exec(queryString)
      openValueEnd = match?.index || queryString.length

      if openKey
        value = queryString.substr(openValueStart, openValueEnd - openValueStart)
        valueIsntEscaped = value.indexOf('?') isnt -1 or value.indexOf('&') isnt -1
        try
          value = decodeURIComponent(value) unless valueIsntEscaped
        query[openKey] = value

      if match
        openKey = match[1].toLowerCase()
        openValueStart = querySplit.lastIndex

    draft = new Message
      body: query.body || ''
      subject: query.subject || '',
      from: [account.me()]
      date: (new Date)
      draft: true
      pristine: true
      accountId: account.id

    contacts = {}
    for attr in ['to', 'cc', 'bcc']
      if query[attr]
        contacts[attr] = ContactStore.parseContactsInString(query[attr])

    Promise.props(contacts).then (contacts) =>
      draft = _.extend(draft, contacts)
      @_finalizeAndPersistNewMessage(draft).then ({draftClientId}) =>
        @_onPopoutDraftClientId(draftClientId)

  _onDestroyDraft: (draftClientId) =>
    session = @_draftSessions[draftClientId]

    # Immediately reset any pending changes so no saves occur
    if session
      @_doneWithSession(session)

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftClientId: draftClientId))

    NylasEnv.close() if @_isPopout()

  # The user request to send the draft
  _onSendDraft: (draftClientId) =>
    if NylasEnv.config.get("core.sending.sounds")
      SoundRegistry.playSound('hit-send')

    @_draftsSending[draftClientId] = true

    # It's important NOT to call `trigger(draftClientId)` here. At this
    # point there are still unpersisted changes in the DraftStoreProxy. If
    # we `trigger`, we'll briefly display the wrong version of the draft
    # as if it was sending.
    @sessionForClientId(draftClientId)
    .then(@_runExtensionsBeforeSend)
    .then (session) =>
      # Immediately save any pending changes so we don't save after
      # sending
      #
      # We do NOT queue a final {SyncbackDraftTask} before sending because
      # we're going to send the full raw body with the Send are are about
      # to delete the draft anyway.
      #
      # We do, however, need to ensure that all of the pending changes are
      # committed to the Database since we'll look them up again just
      # before send.
      session.changes.commit(force: true, noSyncback: true).then =>
        draft = session.draft()
        # We unfortunately can't give the SendDraftTask the raw draft JSON
        # data because there may still be pending tasks (like a
        # {FileUploadTask}) that will continue to update the draft data.
        opts =
          threadId: draft.threadId
          replyToMessageId: draft.replyToMessageId

        task = new SendDraftTask(draftClientId, opts)
        Actions.queueTask(task)

        # NOTE: We may be done with the session in this window, but there
        # may still be {FileUploadTask}s and other pending draft mutations
        # in the worker window.
        #
        # The send "pending" indicator in the main window is declaratively
        # bound to the existence of a `@_draftSession`. We want to show
        # the pending state immediately even as files are uploading.
        @_doneWithSession(session)
        NylasEnv.close() if @_isPopout()

  _isPopout: ->
    NylasEnv.getWindowType() is "composer"

  # Give third-party plugins an opportunity to sanitize draft data
  _runExtensionsBeforeSend: (session) =>
    Promise.each @extensions(), (ext) ->
      ext.finalizeSessionBeforeSending({session})
    .return(session)

  _onRemoveFile: ({file, messageClientId}) =>
    @sessionForClientId(messageClientId).then (session) ->
      files = _.clone(session.draft().files) ? []
      files = _.reject files, (f) -> f.id is file.id
      session.changes.add({files}, immediate: true)

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

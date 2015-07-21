_ = require 'underscore'
moment = require 'moment'
ipc = require 'ipc'

DraftStoreProxy = require './draft-store-proxy'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
ContactStore = require './contact-store'

SendDraftTask = require '../tasks/send-draft'
DestroyDraftTask = require '../tasks/destroy-draft'

Thread = require '../models/thread'
Contact = require '../models/contact'
Message = require '../models/message'
MessageUtils = require '../models/message-utils'
Actions = require '../actions'

TaskQueue = require './task-queue'

{subjectWithPrefix, generateTempId} = require '../models/utils'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

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
    @listenTo Actions.composePopoutDraft, @_onPopoutDraftLocalId
    @listenTo Actions.composeNewBlankDraft, @_onPopoutBlankDraft

    atom.commands.add 'body',
      'application:new-message': => @_onPopoutBlankDraft()

    # Remember that these two actions only fire in the current window and
    # are picked up by the instance of the DraftStore in the current
    # window.
    @listenTo Actions.sendDraft, @_onSendDraft
    @listenTo Actions.destroyDraft, @_onDestroyDraft

    @listenTo Actions.removeFile, @_onRemoveFile

    atom.onBeforeUnload @_onBeforeUnload

    @_draftSessions = {}
    @_extensions = []

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
    @_pendingEnqueue = {}

    ipc.on 'mailto', @_onHandleMailtoLink

    # TODO: Doesn't work if we do window.addEventListener, but this is
    # fragile. Pending an Atom fix perhaps?

  ######### PUBLIC #######################################################

  # Public: Fetch a {DraftStoreProxy} for displaying and/or editing the
  # draft with `localId`.
  #
  # Example:
  #
  # ```coffee
  # session = DraftStore.sessionForLocalId(localId)
  # session.prepare().then ->
  #    # session.draft() is now ready
  # ```
  #
  # - `localId` The {String} local ID of the draft.
  #
  # Returns a {Promise} that resolves to an {DraftStoreProxy} for the
  # draft once it has been prepared:
  sessionForLocalId: (localId) =>
    if not localId
      console.log((new Error).stack)
      throw new Error("sessionForLocalId requires a localId")
    @_draftSessions[localId] ?= new DraftStoreProxy(localId)
    @_draftSessions[localId].prepare()

  # Public: Look up the sending state of the given draft Id.
  # In popout windows the existance of the window is the sending state.
  isSendingDraft: (draftLocalId) ->
    if atom.isMainWindow()
      task = TaskQueue.findTask(SendDraftTask, {draftLocalId})
      return task? or @_pendingEnqueue[draftLocalId]
    else return @_pendingEnqueue[draftLocalId]

  ###
  Composer Extensions
  ###

  # Public: Returns the extensions registered with the DraftStore.
  extensions: (ext) =>
    @_extensions

  # Public: Registers a new extension with the DraftStore. DraftStore extensions
  # make it possible to extend the editor experience, modify draft contents,
  # display warnings before draft are sent, and more.
  #
  # - `ext` A {DraftStoreExtension} instance.
  #
  registerExtension: (ext) =>
    @_extensions.push(ext)

  # Public: Unregisters the extension provided from the DraftStore.
  #
  # - `ext` A {DraftStoreExtension} instance.
  #
  unregisterExtension: (ext) =>
    @_extensions = _.without(@_extensions, ext)

  ########### PRIVATE ####################################################

  _doneWithSession: (session) ->
    session.cleanup()
    delete @_draftSessions[session.draftLocalId]

  _onBeforeUnload: =>
    promises = []

    # Normally we'd just append all promises, even the ones already
    # fulfilled (nothing to save), but in this case we only want to
    # block window closing if we have to do real work. Calling
    # window.close() within on onbeforeunload could do weird things.
    for key, session of @_draftSessions
      if session.draft()?.pristine
        Actions.queueTask(new DestroyDraftTask(session.draftLocalId))
      else
        promises.push(session.changes.commit())

    if promises.length > 0
      # Important: There are some scenarios where all the promises resolve instantly.
      # Firing atom.close() does nothing if called within an existing beforeUnload
      # handler, so we need to always defer by one tick before re-firing close.
      Promise.settle(promises).then =>
        @_draftSessions = {}
        @_onBeforeUnloadComplete()

      # Stop and wait before closing
      return false
    else
      # Continue closing
      return true

  # For better specs
  _onBeforeUnloadComplete: =>
    _.defer -> atom.close()

  _onDataChanged: (change) =>
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft
    @trigger(change)

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
    for extension in @_extensions
      continue unless extension.prepareNewDraft
      extension.prepareNewDraft(draft)

    # Normally we'd allow the DatabaseStore to create a localId, wait for it to
    # commit a LocalLink and resolve, etc. but it's faster to create one now.
    draftLocalId = generateTempId()

    # Optimistically create a draft session and hand it the draft so that it
    # doesn't need to do a query for it a second from now when the composer wants it.
    @_draftSessions[draftLocalId] = new DraftStoreProxy(draftLocalId, draft)

    Promise.all([
      DatabaseStore.bindToLocalId(draft, draftLocalId)
      DatabaseStore.persistModel(draft)
    ]).then =>
      return Promise.resolve({draftLocalId})

  _newMessageWithContext: ({thread, threadId, message, messageId, popout}, attributesCallback) =>
    return unless NamespaceStore.current()

    # We accept all kinds of context. You can pass actual thread and message objects,
    # or you can pass Ids and we'll look them up. Passing the object is preferable,
    # and in most cases "the data is right there" anyway. Lookups add extra latency
    # that feels bad.
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

    # Waits for the query promises to resolve and then resolve with a hash
    # of their resolved values. *swoon*
    Promise.props(queries).then ({thread, message}) =>
      attributes = attributesCallback(thread, message)
      attributes.subject ?= subjectWithPrefix(thread.subject, 'Re:')
      attributes.body ?= ""

      contactStrings = (cs) -> _.invoke(cs, "messageName").join(", ")

      if attributes.replyToMessage
        msg = attributes.replyToMessage

        attributes.subject = subjectWithPrefix(msg.subject, 'Re:')
        attributes.replyToMessageId = msg.id
        attributes.body = """
          <br><br><blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            #{msg.replyAttributionLine()}
            <br>
            #{@_formatBodyForQuoting(msg.body)}
          </blockquote>"""
        delete attributes.quotedMessage

      if attributes.forwardMessage
        msg = attributes.forwardMessage
        fields = []
        fields.push("From: #{contactStrings(msg.from)}") if msg.from.length > 0
        fields.push("Subject: #{msg.subject}")
        fields.push("Date: #{msg.formattedDate()}")
        fields.push("To: #{contactStrings(msg.to)}") if msg.to.length > 0
        fields.push("CC: #{contactStrings(msg.cc)}") if msg.cc.length > 0
        fields.push("BCC: #{contactStrings(msg.bcc)}") if msg.bcc.length > 0

        if msg.files?.length > 0
          attributes.files ?= []
          attributes.files = attributes.files.concat(msg.files)

        attributes.subject = subjectWithPrefix(msg.subject, 'Fwd:')
        attributes.body = """
          <br><br><blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            Begin forwarded message:
            <br><br>
            #{fields.join('<br>')}
            <br><br>
            #{@_formatBodyForQuoting(msg.body)}
          </blockquote>"""
        delete attributes.forwardedMessage

      draft = new Message _.extend {}, attributes,
        from: [NamespaceStore.current().me()]
        date: (new Date)
        draft: true
        pristine: true
        threadId: thread.id
        namespaceId: thread.namespaceId

      @_finalizeAndPersistNewMessage(draft).then ({draftLocalId}) =>
        Actions.composePopoutDraft(draftLocalId) if popout


  # Eventually we'll want a nicer solution for inline attachments
  _formatBodyForQuoting: (body="") =>
    cidRE = MessageUtils.cidRegexString
    # Be sure to match over multiple lines with [\s\S]*
    # Regex explanation here: https://regex101.com/r/vO6eN2/1
    re = new RegExp("<img.*#{cidRE}[\\s\\S]*?>", "igm")
    body.replace(re, "")

  _onPopoutBlankDraft: =>
    namespace = NamespaceStore.current()
    return unless namespace

    draft = new Message
      body: ""
      from: [namespace.me()]
      date: (new Date)
      draft: true
      pristine: true
      namespaceId: namespace.id

    @_finalizeAndPersistNewMessage(draft).then ({draftLocalId}) =>
      @_onPopoutDraftLocalId(draftLocalId, {newDraft: true})

  _onPopoutDraftLocalId: (draftLocalId, options = {}) =>
    return unless NamespaceStore.current()

    save = Promise.resolve()
    if @_draftSessions[draftLocalId]
      save = @_draftSessions[draftLocalId].changes.commit()

    title = if options.newDraft then "New Message" else "Message"

    save.then =>
      atom.newWindow
        title: title
        windowType: "composer"
        windowProps: _.extend(options, {draftLocalId})

  _onHandleMailtoLink: (urlString) =>
    namespace = NamespaceStore.current()
    return unless namespace

    try
      urlString = decodeURI(urlString)

    [whole, to, query] = /mailto:[//]?([^\?]*)[\?]?(.*)/.exec(urlString)

    query = require('querystring').parse(query)
    query.to = to

    draft = new Message
      body: query.body || ''
      subject: query.subject || '',
      from: [namespace.me()]
      date: (new Date)
      draft: true
      pristine: true
      namespaceId: namespace.id

    for attr in ['to', 'cc', 'bcc']
      if query[attr]
        draft[attr] = ContactStore.parseContactsInString(query[attr])

    @_finalizeAndPersistNewMessage(draft).then ({draftLocalId}) =>
      @_onPopoutDraftLocalId(draftLocalId)

  _onDestroyDraft: (draftLocalId) =>
    session = @_draftSessions[draftLocalId]

    # Immediately reset any pending changes so no saves occur
    if session
      session.changes.reset()
      @_doneWithSession(session)

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftLocalId))

    atom.close() if @_isPopout()

  # The user request to send the draft
  _onSendDraft: (draftLocalId) =>
    @_pendingEnqueue[draftLocalId] = true
    @sessionForLocalId(draftLocalId).then (session) =>
      @_runExtensionsBeforeSend(session)

      # Immediately save any pending changes so we don't save after sending
      session.changes.commit().then =>
        task = new SendDraftTask(draftLocalId, {fromPopout: @_isPopout()})

        if atom.isMainWindow()
          # We need to wait for performLocal to finish before `trigger`ing.
          # Only when `performLocal` is done will the task be on the
          # TaskQueue. When we `trigger` listeners should be able to call
          # `isSendingDraft` and have it accurately return true.
          task.waitForPerformLocal().then =>
            # As far as this window is concerned, we're not making any more
            # edits and are destroying the session. If there are errors down
            # the line, we'll make a new session and handle them later
            @_doneWithSession(session)
            @_pendingEnqueue[draftLocalId] = false
            @trigger()

        Actions.queueTask(task)
        @_doneWithSession(session)
        atom.close() if @_isPopout()

  _isPopout: ->
    atom.getWindowType() is "composer"

  # Give third-party plugins an opportunity to sanitize draft data
  _runExtensionsBeforeSend: (session) ->
    for extension in @_extensions
      continue unless extension.finalizeSessionBeforeSending
      extension.finalizeSessionBeforeSending(session)

  _onRemoveFile: ({file, messageLocalId}) =>
    @sessionForLocalId(messageLocalId).then (session) ->
      files = _.clone(session.draft().files) ? []
      files = _.reject files, (f) -> f.id is file.id
      session.changes.add({files}, immediate: true)


module.exports = new DraftStore()

_ = require 'underscore'
moment = require 'moment'
ipc = require 'ipc'

DraftStoreProxy = require './draft-store-proxy'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
ContactStore = require './contact-store'

SendDraftTask = require '../tasks/send-draft'
DestroyDraftTask = require '../tasks/destroy-draft'

Thread = require '../models/thread'
Contact = require '../models/contact'
Message = require '../models/message'
MessageUtils = require '../models/message-utils'
Actions = require '../actions'

TaskQueue = require './task-queue'

{subjectWithPrefix} = require '../models/utils'
{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'
DOMUtils = require '../../dom-utils'

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
    @listenTo Actions.composePopoutDraft, @_onPopoutDraftClientId
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
    @_draftsSending = {}

    ipc.on 'mailto', @_onHandleMailtoLink

    # TODO: Doesn't work if we do window.addEventListener, but this is
    # fragile. Pending an Atom fix perhaps?

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
    return @_draftsSending[draftClientId]?

  ###
  Composer Extensions
  ###

  # Public: Returns the extensions registered with the DraftStore.
  extensions: =>
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
    session.teardown()
    delete @_draftSessions[session.draftClientId]

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
      # Firing atom.close() does nothing if called within an existing beforeUnload
      # handler, so we need to always defer by one tick before re-firing close.
      Promise.settle(promises).then =>
        @_draftSessions = {}
        atom.finishUnload()

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

    # Optimistically create a draft session and hand it the draft so that it
    # doesn't need to do a query for it a second from now when the composer wants it.
    @_draftSessions[draft.clientId] = new DraftStoreProxy(draft.clientId, draft)

    DatabaseStore.persistModel(draft).then =>
      Promise.resolve(draftClientId: draft.clientId)

  _newMessageWithContext: ({thread, threadId, message, messageId, popout}, attributesCallback) =>
    return unless AccountStore.current()

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

      contactsAsHtml = (cs) ->
        DOMUtils.escapeHTMLCharacters(_.invoke(cs, "toString").join(", "))

      if attributes.replyToMessage
        replyToMessage = attributes.replyToMessage

        attributes.subject = subjectWithPrefix(replyToMessage.subject, 'Re:')
        attributes.replyToMessageId = replyToMessage.id
        attributes.body = """
          <br><br><blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            #{DOMUtils.escapeHTMLCharacters(replyToMessage.replyAttributionLine())}
            <br>
            #{@_formatBodyForQuoting(replyToMessage.body)}
          </blockquote>"""
        delete attributes.quotedMessage

      if attributes.forwardMessage
        forwardMessage = attributes.forwardMessage
        fields = []
        fields.push("From: #{contactsAsHtml(forwardMessage.from)}") if forwardMessage.from.length > 0
        fields.push("Subject: #{forwardMessage.subject}")
        fields.push("Date: #{forwardMessage.formattedDate()}")
        fields.push("To: #{contactsAsHtml(forwardMessage.to)}") if forwardMessage.to.length > 0
        fields.push("CC: #{contactsAsHtml(forwardMessage.cc)}") if forwardMessage.cc.length > 0
        fields.push("BCC: #{contactsAsHtml(forwardMessage.bcc)}") if forwardMessage.bcc.length > 0

        if forwardMessage.files?.length > 0
          attributes.files ?= []
          attributes.files = attributes.files.concat(forwardMessage.files)

        attributes.subject = subjectWithPrefix(forwardMessage.subject, 'Fwd:')
        attributes.body = """
          <br><br><blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            Begin forwarded message:
            <br><br>
            #{fields.join('<br>')}
            <br><br>
            #{@_formatBodyForQuoting(forwardMessage.body)}
          </blockquote>"""
        delete attributes.forwardedMessage

      draft = new Message _.extend {}, attributes,
        from: [AccountStore.current().me()]
        date: (new Date)
        draft: true
        pristine: true
        threadId: thread.id
        accountId: thread.accountId

      @_finalizeAndPersistNewMessage(draft).then ({draftClientId}) =>
        Actions.composePopoutDraft(draftClientId) if popout


  # Eventually we'll want a nicer solution for inline attachments
  _formatBodyForQuoting: (body="") =>
    cidRE = MessageUtils.cidRegexString
    # Be sure to match over multiple lines with [\s\S]*
    # Regex explanation here: https://regex101.com/r/vO6eN2/1
    re = new RegExp("<img.*#{cidRE}[\\s\\S]*?>", "igm")
    body.replace(re, "")

  _onPopoutBlankDraft: =>
    account = AccountStore.current()
    return unless account

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
    return unless AccountStore.current()

    if not draftClientId?
      throw new Error("DraftStore::onPopoutDraftId - You must provide a draftClientId")

    save = Promise.resolve()
    if @_draftSessions[draftClientId]
      save = @_draftSessions[draftClientId].changes.commit()

    title = if options.newDraft then "New Message" else "Message"

    save.then =>
      atom.newWindow
        title: title
        windowType: "composer"
        windowProps: _.extend(options, {draftClientId})

  _onHandleMailtoLink: (urlString) =>
    account = AccountStore.current()
    return unless account

    try
      urlString = decodeURI(urlString)

    [whole, to, query] = /mailto:[//]?([^\?]*)[\?]?(.*)/.exec(urlString)

    query = require('querystring').parse(query)
    query.to = to

    for key, val of query
      query[key.toLowerCase()] = val

    draft = new Message
      body: query.body || ''
      subject: query.subject || '',
      from: [account.me()]
      date: (new Date)
      draft: true
      pristine: true
      accountId: account.id

    for attr in ['to', 'cc', 'bcc']
      if query[attr]
        draft[attr] = ContactStore.parseContactsInString(query[attr])

    @_finalizeAndPersistNewMessage(draft).then ({draftClientId}) =>
      @_onPopoutDraftClientId(draftClientId)

  _onDestroyDraft: (draftClientId) =>
    session = @_draftSessions[draftClientId]

    # Immediately reset any pending changes so no saves occur
    if session
      @_doneWithSession(session)

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftClientId: draftClientId))

    atom.close() if @_isPopout()

  # The user request to send the draft
  _onSendDraft: (draftClientId) =>
    @_draftsSending[draftClientId] = true
    @trigger(draftClientId)

    @sessionForClientId(draftClientId).then (session) =>
      @_runExtensionsBeforeSend(session)

      # Immediately save any pending changes so we don't save after sending
      session.changes.commit().then =>
        task = new SendDraftTask(draftClientId, {fromPopout: @_isPopout()})
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

  _onRemoveFile: ({file, messageClientId}) =>
    @sessionForClientId(messageClientId).then (session) ->
      files = _.clone(session.draft().files) ? []
      files = _.reject files, (f) -> f.id is file.id
      session.changes.add({files}, immediate: true)


module.exports = new DraftStore()

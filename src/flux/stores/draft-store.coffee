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

{subjectWithPrefix} = require '../models/utils'

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
      return task?
    else return false

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
        promise = session.changes.commit()
        promises.push(promise) unless promise.isFulfilled()

    if promises.length > 0
      Promise.settle(promises).then =>
        @_draftSessions = {}
        atom.close()

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

  _isMe: (contact={}) =>
    contact.email is NamespaceStore.current().me().email

  _onComposeReply: (context) =>
    @_newMessageWithContext context, (thread, message) =>
      if @_isMe(message.from[0])
        to = message.to
      else if message.replyTo.length
        to = message.replyTo
      else
        to = message.from

      return {
        replyToMessage: message
        to: to
      }

  _onComposeReplyAll: (context) =>
    @_newMessageWithContext context, (thread, message) =>
      if @_isMe(message.from[0])
        to = message.to
        cc = message.cc
      else
        excluded = message.from.map (c) -> c.email
        excluded.push(NamespaceStore.current().me().email)
        if message.replyTo.length
          to = message.replyTo
        else
          to = message.from
        cc = [].concat(message.cc, message.to).filter (p) ->
          !_.contains(excluded, p.email)

      return {
        replyToMessage: message
        to: to
        cc: cc
      }

  _onComposeForward: (context) =>
    @_newMessageWithContext context, (thread, message) ->
      forwardMessage: message

  _newMessageWithContext: ({threadId, messageId}, attributesCallback) =>
    return unless NamespaceStore.current()

    queries = {}
    queries.thread = DatabaseStore.find(Thread, threadId)
    if messageId?
      queries.message = DatabaseStore.find(Message, messageId)
    else
      queries.message = DatabaseStore.findBy(Message, {threadId: threadId}).order(Message.attributes.date.descending()).limit(1)

    # Make sure message body is included
    queries.message.include(Message.attributes.body)

    # Waits for the query promises to resolve and then resolve with a hash
    # of their resolved values. *swoon*
    Promise.props(queries).then ({thread, message}) =>
      attributes = attributesCallback(thread, message)
      attributes.subject ?= subjectWithPrefix(thread.subject, 'Re:')
      attributes.body ?= ""

      # A few helpers for formatting
      contactString = (c) ->
        if c.name then "#{c.name} &lt;#{c.email}&gt;" else c.email
      contactStrings = (cs) ->
        _.map(cs, contactString).join(", ")
      messageDate = (d) ->
        moment(d).format("MMM D YYYY, [at] h:mm a")

      if attributes.replyToMessage
        msg = attributes.replyToMessage
        contact = msg.from[0] ? new Contact(name: 'Unknown', email:'Unknown')
        attribution = "On #{messageDate(msg.date)}, #{contactString(contact)} wrote:"

        attributes.subject = subjectWithPrefix(msg.subject, 'Re:')
        attributes.replyToMessageId = msg.id
        attributes.body = """
          <br><br><blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            #{attribution}
            <br>
            #{@_formatBodyForQuoting(msg.body)}
          </blockquote>"""
        delete attributes.quotedMessage

      if attributes.forwardMessage
        msg = attributes.forwardMessage
        fields = []
        fields.push("From: #{contactStrings(msg.from)}") if msg.from.length > 0
        fields.push("Subject: #{msg.subject}")
        fields.push("Date: #{messageDate(msg.date)}")
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

      DatabaseStore.persistModel(draft)

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
    DatabaseStore.persistModel(draft).then =>
      DatabaseStore.localIdForModel(draft).then(@_onPopoutDraftLocalId)

  _onPopoutDraftLocalId: (draftLocalId, options = {}) =>
    return unless NamespaceStore.current()

    options.draftLocalId = draftLocalId

    atom.newWindow
      title: "Message"
      windowType: "composer"
      windowProps: options

  _onHandleMailtoLink: (urlString) =>
    namespace = NamespaceStore.current()
    return unless namespace

    url = require 'url'
    qs = require 'querystring'
    parts = url.parse(urlString)
    query = qs.parse(parts.query)
    query.to = "#{parts.auth}@#{parts.host}"

    draft = new Message
      body: query.body || ''
      subject: query.subject || '',
      from: [namespace.me()]
      date: (new Date)
      draft: true
      pristine: true
      namespaceId: namespace.id

    contactForEmail = (email) ->
      match = ContactStore.searchContacts(email, 1)
      return match[0] if match[0]
      return new Contact({email})

    for attr in ['to', 'cc', 'bcc']
      draft[attr] = query[attr]?.split(',').map(contactForEmail) || []

    DatabaseStore.persistModel(draft).then =>
      DatabaseStore.localIdForModel(draft).then(@_onPopoutDraftLocalId)

  _onDestroyDraft: (draftLocalId) =>
    session = @_draftSessions[draftLocalId]

    if not session
      throw new Error("Couldn't find the draft session in the current window")

    # Immediately reset any pending changes so no saves occur
    session.changes.reset()

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftLocalId))

    @_doneWithSession(session)

    atom.close() if @_isPopout()

  # The user request to send the draft
  _onSendDraft: (draftLocalId) =>
    @sessionForLocalId(draftLocalId).then (session) =>
      @_runExtensionsBeforeSend(session)

      # Immediately save any pending changes so we don't save after sending
      session.changes.commit().then =>

        task = new SendDraftTask draftLocalId, {fromPopout: @_isPopout()}
        Actions.queueTask(task)

        # As far as this window is concerned, we're not making any more
        # edits and are destroying the session. If there are errors down
        # the line, we'll make a new session and handle them later
        @_doneWithSession(session)
        @trigger()

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
      session.changes.add({files}, true)


module.exports = new DraftStore()

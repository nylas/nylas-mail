_ = require 'underscore-plus'
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

    @listenTo Actions.sendDraft, @_onSendDraft
    @listenTo Actions.destroyDraft, @_onDestroyDraft

    @listenTo Actions.removeFile, @_onRemoveFile
    @listenTo Actions.attachFileComplete, @_onAttachFileComplete

    @listenTo Actions.sendDraftError, @_onSendDraftError
    @listenTo Actions.sendDraftSuccess, @_onSendDraftSuccess

    atom.onBeforeUnload @_onBeforeUnload

    @_draftSessions = {}
    @_sendingState = {}
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
  # draft:
  sessionForLocalId: (localId) =>
    if not localId
      console.log((new Error).stack)
      throw new Error("sessionForLocalId requires a localId")
    @_draftSessions[localId] ?= new DraftStoreProxy(localId)
    @_draftSessions[localId].prepare()

  # Public: Look up the sending state of the given draft Id.
  sendingState: (draftLocalId) -> @_sendingState[draftLocalId] ? false

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

  cleanupSessionForLocalId: (localId) =>
    session = @_draftSessions[localId]
    return unless session

    draft = session.draft()
    Actions.queueTask(new DestroyDraftTask(localId)) if draft.pristine

    if atom.getWindowType() is "composer"
      # Sometimes we swap out one ID for another. In that case we don't
      # want to close while it's swapping. We are using a defer here to
      # give the swap code time to put the new ID in the @_draftSessions.
      #
      # This defer hack prevents us from having to pass around a lock or a
      # parameter through functions who may do this in other parts of the
      # application.
      _.defer =>
        if Object.keys(@_draftSessions).length is 0
          atom.close()

    if atom.isMainWindow()
      session.cleanup()

    delete @_draftSessions[localId]

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

  _isMe: (contact={}) =>
    contact.email is NamespaceStore.current().me().email

  _onComposeReply: (context) =>
    @_newMessageWithContext context, (thread, message) =>
      if @_isMe(message.from[0])
        to = message.to
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
    # Immediately reset any pending changes so no saves occur
    @_draftSessions[draftLocalId]?.changes.reset()

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftLocalId))

    # Clean up the draft session
    @cleanupSessionForLocalId(draftLocalId)

  _onSendDraft: (draftLocalId) =>
    new Promise (resolve, reject) =>
      @_sendingState[draftLocalId] = true
      @trigger()

      @sessionForLocalId(draftLocalId).then (session) =>
        # Give third-party plugins an opportunity to sanitize draft data
        for extension in @_extensions
          continue unless extension.finalizeSessionBeforeSending
          extension.finalizeSessionBeforeSending(session)

        # Immediately save any pending changes so we don't save after sending
        session.changes.commit().then =>
          # Queue the task to send the draft
          fromPopout = atom.getWindowType() is "composer"
          Actions.queueTask(new SendDraftTask(draftLocalId, fromPopout: fromPopout))

          # Clean up session, close window
          @cleanupSessionForLocalId(draftLocalId)

          resolve()

  _onSendDraftError: (draftLocalId, errorMessage) ->
    @_sendingState[draftLocalId] = false
    if atom.getWindowType() is "composer"
      @_onPopoutDraftLocalId(draftLocalId, {errorMessage})
    @trigger()

  _onSendDraftSuccess: ({draftLocalId}) =>
    @_sendingState[draftLocalId] = false
    @trigger()

  _onAttachFileComplete: ({file, messageLocalId}) =>
    @sessionForLocalId(messageLocalId).then (session) ->
      files = _.clone(session.draft().files) ? []
      files.push(file)
      session.changes.add({files}, true)

  _onRemoveFile: ({file, messageLocalId}) =>
    @sessionForLocalId(messageLocalId).then (session) ->
      files = _.clone(session.draft().files) ? []
      files = _.reject files, (f) -> f.id is file.id
      session.changes.add({files}, true)


module.exports = new DraftStore()

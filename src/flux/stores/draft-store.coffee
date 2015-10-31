_ = require 'underscore'
ipc = require 'ipc'
crypto = require 'crypto'
moment = require 'moment'
sanitizeHtml = require 'sanitize-html'

DraftStoreProxy = require './draft-store-proxy'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
ContactStore = require './contact-store'

SendDraftTask = require '../tasks/send-draft'
DestroyDraftTask = require '../tasks/destroy-draft'

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
RegExpUtils = require '../../regexp-utils'

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

    if atom.isMainWindow()
      ipc.on 'new-message', => @_onPopoutBlankDraft()

    # Remember that these two actions only fire in the current window and
    # are picked up by the instance of the DraftStore in the current
    # window.
    @listenTo Actions.sendDraft, @_onSendDraft
    @listenTo Actions.destroyDraft, @_onDestroyDraft

    @listenTo Actions.removeFile, @_onRemoveFile

    atom.onBeforeUnload @_onBeforeUnload

    @_draftSessions = {}
    @_extensions = []

    @_inlineStylePromises = {}
    @_inlineStyleResolvers = {}

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

    ipc.on 'inline-styles-result', @_onInlineStylesResult

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
    return @_draftsSending[draftClientId] ? false

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
      DatabaseStore.persistModel(draft).then =>
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
    for extension in @_extensions
      continue unless extension.prepareNewDraft
      extension.prepareNewDraft(draft)

    # Optimistically create a draft session and hand it the draft so that it
    # doesn't need to do a query for it a second from now when the composer wants it.
    @_draftSessions[draft.clientId] = new DraftStoreProxy(draft.clientId, draft)

    DatabaseStore.persistModel(draft).then =>
      Promise.resolve(draftClientId: draft.clientId, draft: draft)

  _newMessageWithContext: (args, attributesCallback) =>
    return unless AccountStore.current()

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
    return new Message _.extend {}, attributes,
      from: [AccountStore.current().me()]
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
      @_prepareBodyForQuoting(replyToMessage.body, attributes.clientId).then (body) ->
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
      @_prepareBodyForQuoting(forwardMessage.body, attributes.clientId).then (body) ->
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
  _prepareBodyForQuoting: (body="", clientId) =>
    ## Fix inline images
    cidRE = MessageUtils.cidRegexString
    # Be sure to match over multiple lines with [\s\S]*
    # Regex explanation here: https://regex101.com/r/vO6eN2/1
    re = new RegExp("<img.*#{cidRE}[\\s\\S]*?>", "igm")
    body.replace(re, "")

    ## Remove style tags and inline styles
    # This prevents styles from leaking emails.
    # https://github.com/Automattic/juice
    if (RegExpUtils.looseStyleTag()).test(body)
      @_convertToInlineStyles(body, clientId).then (body) =>
        return @_sanitizeBody(body)
    else
      return Promise.resolve(@_sanitizeBody(body))

  _convertToInlineStyles: (body, clientId) ->
    body = @_injectUserAgentStyles(body)
    @_inlineStylePromises[clientId] ?= new Promise (resolve, reject) =>
      @_inlineStyleResolvers[clientId] = resolve
      ipc.send('inline-style-parse', {body, clientId})
    return @_inlineStylePromises[clientId]

  # This will prepend the user agent stylesheet so we can apply it to the
  # styles properly.
  _injectUserAgentStyles: (body) ->
    # No DOM parsing! Just find the first <style> tag and prepend there.
    i = body.search(RegExpUtils.looseStyleTag())
    return body if i is -1
    userAgentDefault = require '../../chrome-user-agent-stylesheet-string'
    return "#{body[0...i]}<style>#{userAgentDefault}</style>#{body[i..-1]}"

  _onInlineStylesResult: ({body, clientId}) =>
    delete @_inlineStylePromises[clientId]
    @_inlineStyleResolvers[clientId](body)
    delete @_inlineStyleResolvers[clientId]
    return

  _sanitizeBody: (body) ->
    return sanitizeHtml body,
      allowedTags: DOMUtils.permissiveTags()
      allowedAttributes: DOMUtils.permissiveAttributes()
      allowedSchemes: [ 'http', 'https', 'ftp', 'mailto', 'data' ]

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
      app = require('remote').getGlobal('application')
      existing = app.windowManager.windowWithPropsMatching({draftClientId})
      if existing
        existing.restore() if existing.isMinimized()
        existing.focus()
      else
        atom.newWindow
          title: title
          windowType: "composer"
          windowProps: _.extend(options, {draftClientId})

  _onHandleMailtoLink: (urlString) =>
    account = AccountStore.current()
    return unless account

    try
      urlString = decodeURI(urlString)

    [whole, to, query] = /mailto:[//]?([^\?\&]*)[\?\&]?(.*)/.exec(urlString)

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

    atom.close() if @_isPopout()

  # The user request to send the draft
  _onSendDraft: (draftClientId) =>
    if atom.config.get("core.sending.sounds")
      SoundRegistry.playSound('hit-send')

    @_draftsSending[draftClientId] = true
    @trigger(draftClientId)

    @sessionForClientId(draftClientId).then (session) =>
      @_runExtensionsBeforeSend(session)

      # Immediately save any pending changes so we don't save after sending
      #
      # It's important that we force commit the changes before sending.
      # Once committed, we'll queue a `SyncbackDraftTask`. Since we may be
      # sending a draft by its serverId, we need to make sure that the
      # server has the latest changes. It's possible for the
      # session.changes._pending to be empty if the last SyncbackDraftTask
      # failed during its performRemote. When we send we should always try
      # again.
      session.changes.commit(force: true).then =>
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

  _onDraftSendingFailed: ({draftClientId, errorMessage}) ->
    @_draftsSending[draftClientId] = false
    @trigger(draftClientId)
    if atom.isMainWindow()
      # We delay so the view has time to update the restored draft. If we
      # don't delay the modal may come up in a state where the draft looks
      # like it hasn't been restored or has been lost.
      _.delay ->
        remote = require('remote')
        dialog = remote.require('dialog')
        dialog.showMessageBox remote.getCurrentWindow(), {
          type: 'warning'
          buttons: ['Okay'],
          message: "Error"
          detail: errorMessage
        }
      , 100

 module.exports = new DraftStore()

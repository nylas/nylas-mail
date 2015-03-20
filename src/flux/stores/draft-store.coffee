_ = require 'underscore-plus'
moment = require 'moment'

Reflux = require 'reflux'
DraftStoreProxy = require './draft-store-proxy'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'

SendDraftTask = require '../tasks/send-draft'
DestroyDraftTask = require '../tasks/destroy-draft'

Thread = require '../models/thread'
Message = require '../models/message'
Actions = require '../actions'

{subjectWithPrefix} = require '../models/utils'

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

    @listenTo Actions.sendDraft, @_onSendDraft
    @listenTo Actions.destroyDraft, @_onDestroyDraft

    @listenTo Actions.removeFile, @_onRemoveFile
    @listenTo Actions.attachFileComplete, @_onAttachFileComplete

    @listenTo Actions.sendDraftError, @_onSendDraftSuccess
    @listenTo Actions.sendDraftSuccess, @_onSendDraftError

    @listenTo Actions.destroyDraftSuccess, @_closeWindow
    @_drafts = []
    @_draftSessions = {}
    @_sendingState = {}
    @_extensions = []

    # TODO: Doesn't work if we do window.addEventListener, but this is
    # fragile. Pending an Atom fix perhaps?
    window.onbeforeunload = (event) =>
      promises = []

      # Normally we'd just append all promises, even the ones already
      # fulfilled (nothing to save), but in this case we only want to
      # block window closing if we have to do real work. Calling
      # window.close() within on onbeforeunload could do weird things.
      for key, session of @_draftSessions
        promise = session.changes.commit()
        if not promise.isFulfilled()
          promises.push(promise)

      if promises.length > 0
        Promise.settle(promises).then =>
          @_draftSessions = {}
          window.close()

        # Stop and wait before closing
        return false
      else
        # Continue closing
        return true

    DatabaseStore.findAll(Message, draft: true).then (drafts) =>
      @_drafts = drafts
      @trigger({})

  ######### PUBLIC #######################################################

  # Returns a promise

  items: ->
    @_drafts

  sessionForLocalId: (localId) ->
    @_draftSessions[localId] ?= new DraftStoreProxy(localId)
    @_draftSessions[localId]

  sendingState: (draftLocalId) -> @_sendingState[draftLocalId] ? false

  # Composer Extensions

  extensions: (ext) ->
    @_extensions

  registerExtension: (ext) ->
    @_extensions.push(ext)

  unregisterExtension: (ext) ->
    @_extensions = _.without(@_extensions, ext)

  ########### PRIVATE ####################################################

  _onDataChanged: (change) ->
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft

    DatabaseStore.findAll(Message, draft: true).then (drafts) =>
      @_drafts = drafts
      @trigger(change)

  _onComposeReply: (context) ->
    @_newMessageWithContext context, (thread, message) ->
      replyToMessage: message
      to: message.from

  _onComposeReplyAll: (context) ->
    @_newMessageWithContext context, (thread, message) ->
      excluded = message.from.map (c) -> c.email
      excluded.push(NamespaceStore.current().me().email)

      replyToMessage: message
      to: message.from
      cc: [].concat(message.cc, message.to).filter (p) ->
        !_.contains(excluded, p.email)

  _onComposeForward: (context) ->
    @_newMessageWithContext context, (thread, message) ->
      forwardMessage: message

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
      attributes.subject ?= subjectWithPrefix(thread.subject, 'Re:')

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
          <br><br>
          <blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            #{attribution}
            <br>
            #{msg.body}
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

        attributes.subject = subjectWithPrefix(msg.subject, 'Fwd:')
        attributes.body = """
          <br><br>
          <blockquote class="gmail_quote"
            style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
            Begin forwarded message:
            <br><br>
            #{fields.join('<br>')}
            <br><br>
            #{msg.body}
          </blockquote>"""
        delete attributes.forwardedMessage

      draft = new Message _.extend {}, attributes,
        from: [NamespaceStore.current().me()]
        date: (new Date)
        draft: true
        threadId: thread.id
        namespaceId: thread.namespaceId

      DatabaseStore.persistModel(draft)

  # We only want to close the popout window if we're sure various draft
  # actions succeeded.
  _closeWindow: (draftLocalId) ->
    if atom.state.mode is "composer" and @_draftSessions[draftLocalId]?
      atom.close()

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
    # Immediately reset any pending changes so no saves occur
    @_closeWindow(draftLocalId)
    @_draftSessions[draftLocalId]?.changes.reset()
    delete @_draftSessions[draftLocalId]

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftLocalId))

  _onSendDraft: (draftLocalId) ->
    new Promise (resolve, reject) =>
      @_sendingState[draftLocalId] = true
      @trigger()

      session = @sessionForLocalId(draftLocalId)
      session.prepare().then =>
        # Give third-party plugins an opportunity to sanitize draft data
        for extension in @_extensions
          continue unless extension.finalizeSessionBeforeSending
          extension.finalizeSessionBeforeSending(session)

        # Immediately save any pending changes so we don't save after sending
        session.changes.commit().then =>
          # We optimistically close the window. If we get an error, then it
          # will re-open again.
          @_closeWindow(draftLocalId)
          # Queue the task to send the draft
          fromPopout = atom.state.mode is "composer"
          Actions.queueTask(new SendDraftTask(draftLocalId, fromPopout: fromPopout))
          resolve()

  _onSendDraftError: (draftLocalId) ->
    @_sendingState[draftLocalId] = false
    @trigger()

  _onSendDraftSuccess: (draftLocalId) ->
    @_sendingState[draftLocalId] = false
    @trigger()

  _onAttachFileComplete: ({file, messageLocalId}) ->
    @sessionForLocalId(messageLocalId).prepare().then (proxy) ->
      files = proxy.draft().files ? []
      files.push(file)
      proxy.changes.add({files}, true)

  _onRemoveFile: ({file, messageLocalId}) ->
    @sessionForLocalId(messageLocalId).prepare().then (proxy) ->
      files = proxy.draft().files ? []
      files = _.reject files, (f) -> f.id is file.id
      proxy.changes.add({files}, true)

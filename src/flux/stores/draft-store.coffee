_ = require 'underscore-plus'
moment = require 'moment'
ipc = require 'ipc'

Reflux = require 'reflux'
DraftStoreProxy = require './draft-store-proxy'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'

SendDraftTask = require '../tasks/send-draft'
DestroyDraftTask = require '../tasks/destroy-draft'

Thread = require '../models/thread'
Message = require '../models/message'
MessageUtils = require '../models/message-utils'
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

    atom.commands.add 'body',
      'application:new-message': => @_onComposeNewBlankDraft()

    @listenTo Actions.sendDraft, @_onSendDraft
    @listenTo Actions.destroyDraft, @_onDestroyDraft

    @listenTo Actions.removeFile, @_onRemoveFile
    @listenTo Actions.attachFileComplete, @_onAttachFileComplete

    @listenTo Actions.sendDraftError, @_onSendDraftSuccess
    @listenTo Actions.sendDraftSuccess, @_onSendDraftError

    @_draftSessions = {}
    @_sendingState = {}
    @_extensions = []

    ipc.on 'mailto', (mailToJSON) =>
      return unless atom.isMainWindow()
      atom.newWindow @_composerWindowProps(draftInitialJSON: mailToJSON)

    # TODO: Doesn't work if we do window.addEventListener, but this is
    # fragile. Pending an Atom fix perhaps?
    window.onbeforeunload = => @_onBeforeUnload()

  ######### PUBLIC #######################################################

  # Returns a promise

  sessionForLocalId: (localId) ->
    if not localId
      console.log((new Error).stack)
      throw new Error("sessionForLocalId requires a localId")
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
 
  cleanupSessionForLocalId: (localId) ->
    return unless @_draftSessions[localId]

    draft = @_draftSessions[localId].draft()
    Actions.queueTask(new DestroyDraftTask(localId)) if draft.pristine

    if atom.getWindowType() is "composer"
      atom.close()

    if atom.isMainWindow()
      @_draftSessions[localId].cleanup()
      delete @_draftSessions[localId]

  _onBeforeUnload: ->
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
        window.close()

      # Stop and wait before closing
      return false
    else
      # Continue closing
      return true

  _onDataChanged: (change) ->
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft

  _isMe: (contact={}) ->
    contact.email is NamespaceStore.current().me().email

  _onComposeReply: (context) ->
    @_newMessageWithContext context, (thread, message) =>
      if @_isMe(message.from[0])
        to = message.to
      else
        to = message.from

      return {
        replyToMessage: message
        to: to
      }

  _onComposeReplyAll: (context) ->
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
  _formatBodyForQuoting: (body="") ->
    cidRE = MessageUtils.cidRegexString
    # Be sure to match over multiple lines with [\s\S]*
    # Regex explanation here: https://regex101.com/r/vO6eN2/1
    re = new RegExp("<img.*#{cidRE}[\\s\\S]*?>", "igm")
    body.replace(re, "")

  # The logic to create a new Draft used to be in the DraftStore (which is
  # where it should be). It got moved to composer/lib/main.cjsx becaues
  # of an obscure atom-shell/Chrome bug whereby database requests firing right
  # before the new-window loaded would cause the new-window to load with
  # about:blank instead of its contents. By moving the DB logic there, we can
  # get around this.
  _onComposeNewBlankDraft: ->
    atom.newWindow @_composerWindowProps()

  _onComposePopoutDraft: (draftLocalId) ->
    atom.newWindow @_composerWindowProps(draftLocalId: draftLocalId)

  _composerWindowProps: (props={}) ->
    title: "Message"
    windowType: "composer"
    windowProps: _.extend {}, props, createNew: true

  _onDestroyDraft: (draftLocalId) ->
    # Immediately reset any pending changes so no saves occur
    @_draftSessions[draftLocalId]?.changes.reset()

    # Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftLocalId))

    # Clean up the draft session
    @cleanupSessionForLocalId(draftLocalId)

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
          # Queue the task to send the draft
          fromPopout = atom.getWindowType() is "composer"
          Actions.queueTask(new SendDraftTask(draftLocalId, fromPopout: fromPopout))

          # Clean up session, close window
          @cleanupSessionForLocalId(draftLocalId)

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

_ = require 'underscore'
{Thread,
 Actions,
 MailViewFilter,
 AccountStore,
 CategoryStore,
 SoundRegistry,
 DatabaseStore} = require 'nylas-exports'

module.exports =

  config:
    enabled:
      type: 'boolean'
      default: true

  activate: ->
    @unlisteners = []
    @unlisteners.push Actions.didPassivelyReceiveNewModels.listen(@_onNewMailReceived, @)
    @activationTime = Date.now()
    @stack = []
    @stackProcessTimer = null

  deactivate: ->
    fn() for fn in @unlisteners

  serialize: ->

  _notifyAll: ->
    new Notification("#{@stack.length} Unread Messages", {
      tag: 'unread-update'
    })
    @stack = []

  _notifyOne: ({message, thread}) ->
    body = message.subject
    if not body or body.length is 0
      body = message.snippet
    from = message.from[0]?.displayName() ? "Unknown"

    notif = new Notification(from, {
      body: body
      tag: 'unread-update'
    })
    notif.onclick = =>
      atom.displayWindow()
      if AccountStore.current().id isnt thread.accountId
        Actions.selectAccountId(thread.accountId)

      MailViewFilter filter = MailViewFilter.forCategory(thread.categoryNamed('inbox'))
      Actions.focusMailView(filter)
      Actions.setFocus(collection: 'thread', item: thread)

  _notifyMessages: ->
    if @stack.length >= 5
      @_notifyAll()
    else if @stack.length > 0
      @_notifyOne(@stack.pop())

    @stackProcessTimer = null
    if @stack.length > 0
      @stackProcessTimer = setTimeout(( => @_notifyMessages()), 2000)

  # https://phab.nylas.com/D2188
  _onNewMessagesMissingThreads: (messages) ->
    setTimeout =>
      threads = {}
      for msg in messages
        threads[msg.threadId] ?= DatabaseStore.find(Thread, msg.threadId)
      Promise.props(threads).then (threads) =>
        messages = _.filter messages, (msg) =>
          threads[msg.threadId]?
        if messages.length > 0
          @_onNewMailReceived({message: messages, thread: _.values(threads)})
    , 10000

  _onNewMailReceived: (incoming) ->
    new Promise (resolve, reject) =>
      return resolve() if atom.config.get('core.notifications.enabled') is false

      incomingMessages = incoming['message'] ? []
      incomingThreads = incoming['thread'] ? []

      # Filter for new messages that are not sent by the current user
      newUnread = _.filter incomingMessages, (msg) =>
        isUnread = msg.unread is true
        isNew = msg.date?.valueOf() >= @activationTime
        isFromMe = msg.isFromMe()
        return isUnread and isNew and not isFromMe

      return resolve() if newUnread.length is 0

      # For each message, find it's corresponding thread. First, look to see
      # if it's already in the `incoming` payload (sent via delta sync
      # at the same time as the message.) If it's not, try loading it from
      # the local cache.
      #
      # Note we may receive multiple unread msgs for the same thread.
      # Using a map and ?= to avoid repeating work.
      threads = {}
      for msg in newUnread
        threads[msg.threadId] ?= _.findWhere(incomingThreads, {id: msg.threadId})
        threads[msg.threadId] ?= DatabaseStore.find(Thread, msg.threadId)

      Promise.props(threads).then (threads) =>
        # Filter new unread messages to just the ones in the inbox
        newUnreadInInbox = _.filter newUnread, (msg) ->
          threads[msg.threadId]?.categoryNamed('inbox')

        # Filter messages that we can't decide whether to display or not
        # since no associated Thread object has arrived yet.
        newUnreadMissingThreads = _.filter newUnread, (msg) ->
          not threads[msg.threadId]?

        if newUnreadMissingThreads.length > 0
          @_onNewMessagesMissingThreads(newUnreadMissingThreads)

        return resolve() if newUnreadInInbox.length is 0
        if atom.config.get("core.notifications.sounds")
          SoundRegistry.playSound('new-mail')

        for msg in newUnreadInInbox
          @stack.push({message: msg, thread: threads[msg.threadId]})
        if not @stackProcessTimer
          @_notifyMessages()

        resolve()

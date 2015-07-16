_ = require 'underscore'
{Thread,
 Actions,
 CategoryStore,
 DatabaseStore,
 NamespaceStore} = require 'nylas-exports'

module.exports =
  activate: ->
    @unlisteners = []
    @unlisteners.push Actions.didPassivelyReceiveNewModels.listen(@_onNewMailReceived, @)
    @activationTime = Date.now()

  deactivate: ->
    fn() for fn in @unlisteners

  serialize: ->

  _notifyMessage: (msg) ->
    body = msg.subject
    if not body or body.length is 0
      body = msg.snippet
    from = msg.from[0]?.displayName() ? "Unknown"
    notif = new Notification(from, {
      body: body
      tag: 'unread-update'
    })

    notif.onclick = =>
      atom.displayWindow()
      Actions.focusCategory(CategoryStore.getStandardCategory("inbox"))
      Actions.setFocus(collection: 'thread', item: @threads[msg.threadId])

  _notifyMessages: (msgs) ->

    return if msgs.length is 0
    @_notifyMessage(msgs.pop())
    setTimeout (=> @_notifyMessages msgs), 2000

  _onNewMailReceived: (incoming) ->
    new Promise (resolve, reject) =>
      incomingMessages = incoming['message'] ? []
      incomingThreads = incoming['thread'] ? []

      # Filter for new messages that are not sent by the current user
      myEmail = NamespaceStore.current().emailAddress
      newUnread = _.filter incomingMessages, (msg) =>
        isUnread = msg.unread is true
        isNew = msg.date?.valueOf() >= @activationTime
        isFromMe = msg.from[0]?.email is myEmail
        return isUnread and isNew and not isFromMe

      return resolve() if newUnread.length is 0

      # For each message, find it's corresponding thread. First, look to see
      # if it's already in the `incoming` payload (sent via delta sync
      # at the same time as the message.) If it's not, try loading it from
      # the local cache.
      #
      # Note we may receive multiple unread msgs for the same thread.
      # Using a map and ?= to avoid repeating work.
      @threads = {}
      for msg in newUnread
        @threads[msg.threadId] ?= _.findWhere(incomingThreads, {id: msg.threadId})
        @threads[msg.threadId] ?= DatabaseStore.find(Thread, msg.threadId)

      Promise.props(@threads).then (threads) =>

        # Filter new unread messages to just the ones in the inbox
        newUnreadInInbox = _.filter newUnread, (msg) ->
          threads[msg.threadId]?.hasCategoryName('inbox')

        return resolve() if newUnreadInInbox.length is 0
        atom.playSound('new_mail.ogg')

        if newUnreadInInbox.length < 5
          @_notifyMessages(newUnreadInInbox)
        else
          new Notification("#{newUnreadInInbox.length} Unread Messages", {
            tag: 'unread-update'
          })

        resolve()

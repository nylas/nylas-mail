_ = require 'underscore-plus'
{Actions} = require 'inbox-exports'

module.exports =
  activate: ->
    @unlisteners = []
    @unlisteners.push Actions.didPassivelyReceiveNewModels.listen(@_onNewMailReceived, @)
    @activationTime = Date.now()

  deactivate: ->
    fn() for fn in @unlisteners

  serialize: ->

  _onNewMailReceived: (models) ->
    # Display a notification if we've received new messages
    newUnreadMessages = _.filter (models['message'] ? []), (msg) =>
      msg.unread is true and msg.date?.valueOf() >= @activationTime

    if newUnreadMessages.length is 1
      msg = newUnreadMessages.pop()
      notif = new Notification(msg.from[0].displayName(), {
        body: msg.subject
        tag: 'unread-update'
      })
      notif.onclick = ->
        Actions.selectTagId("inbox")
        Actions.selectThreadId(msg.threadId)

    if newUnreadMessages.length > 1
      new Notification("#{newUnreadMessages.length} Unread Messages", {
        tag: 'unread-update'
      })

    if newUnreadMessages.length > 0
      atom.playSound('new_mail.ogg')

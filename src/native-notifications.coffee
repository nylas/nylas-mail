
class NativeNotifications
  constructor: ->

  displayNotification: ({title, subtitle, body, tag, canReply, onActivate} = {}) =>
    n = new Notification(title, {
      body: subtitle
      tag: tag
    })
    n.onclick = onActivate

module.exports = new NativeNotifications

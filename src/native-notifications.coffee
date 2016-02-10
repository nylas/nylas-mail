
class NativeNotifications
  constructor: ->

  displayNotification: ({title, subtitle, body, tag, canReply, onActivate} = {}) =>
    n = new Notification(title, {
      silent: true
      body: subtitle
      tag: tag
    })
    n.onclick = onActivate

module.exports = new NativeNotifications

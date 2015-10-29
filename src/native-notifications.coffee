ipc = require 'ipc'

class NativeNotifications
  constructor: ->
    @_handlers = {}
    ipc.on 'activate-native-notification', ({tag, activationType, response}) =>
      @_handlers[tag]?({tag, activationType, response})

  displayNotification: ({title, subtitle, body, tag, canReply, onActivate} = {}) =>
    if not tag
      throw new Error("NativeNotifications:displayNotification: A tag is required.")

    if process.platform in ['darwin', 'win32']
      ipc.send('fire-native-notification', {title, subtitle, body, tag, canReply})
      @_handlers[tag] = onActivate
    else
      notif = new Notification(title, {
        tag: tag
        body: subtitle
      })
      notif.onclick = => onActivate({tag, activationType: 'contents-clicked'})

module.exports = new NativeNotifications

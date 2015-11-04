ipc = require 'ipc'
BrowserWindow = require 'browser-window'

class NativeNotificationManagerUnavailable

class NativeNotificationManagerWindows
  constructor: ->

class NativeNotificationManagerMacOSX
  constructor: ->
    @$ = require('nodobjc')
    @$.framework('Foundation')

    @_lastNotifId = 1

    @_center = @$.NSUserNotificationCenter('defaultUserNotificationCenter')
    @_center('removeAllDeliveredNotifications')

    Delegate = @$.NSObject.extend('NylasNotificationDelegate')
    Delegate.addMethod('userNotificationCenter:didActivateNotification:', [@$.void, [Delegate, @$.selector, @$.id, @$.id]], @didActivateNotification)
    Delegate.addMethod('userNotificationCenter:shouldPresentNotification:', ['c', [Delegate, @$.selector, @$.id, @$.id]], @shouldPresentNotification)
    Delegate.register()
    @_delegate = Delegate('alloc')('init')
    @_center('setDelegate', @_delegate)

    # Ensure that these objects are never, ever garbage collected
    global.__nativeNotificationManagerMacOSXDelegate = Delegate
    global.__nativeNotificationManagerMacOSX = @

    ipc.on('fire-native-notification', @onFireNotification)

  shouldPresentNotification: (self, _cmd, center, notif) =>
    return true

  didActivateNotification: (self, _cmd, center, notif) =>
    center("removeDeliveredNotification", notif)

    [header, id, tag] = (""+notif('identifier')).split(':::')

    # Avoid potential conflicts with other libraries that may have pushed
    # notifications on our behalf.
    return unless header is 'N1'

    NSUserNotificationActivationType = [
      "none",
      "contents-clicked",
      "action-clicked",
      "replied",
      "additional-action-clicked"
    ]

    payload =
      tag: tag
      activationType: NSUserNotificationActivationType[(""+notif('activationType'))/1]

    if payload.activationType is "replied"
      payload.response = (""+notif('response')).replace("{\n}", '')
    if payload.response is "null"
      payload.response = null

    console.log("Received notification: " + JSON.stringify(payload))
    BrowserWindow.getAllWindows().forEach (win) ->
      win.webContents.send('activate-native-notification', payload)

  onFireNotification: (event, {title, subtitle, body, tag, canReply}) =>
    # By default on Mac OS X, delivering another notification with the same identifier
    # triggers an update, which does not re-display the notification. To make subsequent
    # calls with the same `tag` redisplay the notification, we:

    # 1. Assign each notification a unique identifier, so it's not considered an update
    identifier = "N1:::#{@_lastNotifId}:::#{tag}"
    @_lastNotifId += 1

    # 2. Manually remove any previous notification with the same tag
    delivered = @_center("deliveredNotifications")
    for existing in delivered
      [x, x, existingTag] = (""+existing('identifier')).split(':::')
      if existingTag is tag
        @_center('removeDeliveredNotification', existing)

    # 3. Fire a new notification
    notification = @$.NSUserNotification('alloc')('init')
    notification('setTitle', @$.NSString('stringWithUTF8String', title))
    notification('setIdentifier', @$.NSString('stringWithUTF8String', identifier))
    notification('setSubtitle', @$.NSString('stringWithUTF8String', subtitle)) if subtitle
    notification('setInformativeText', @$.NSString('stringWithUTF8String', body)) if body
    notification('setHasReplyButton', canReply)
    @_center('deliverNotification', notification)

if process.platform is 'darwin'
  module.exports = NativeNotificationManagerMacOSX
else if process.platform is 'win32'
  module.exports = NativeNotificationManagerWindows
else
  module.exports = NativeNotificationManagerUnavailable

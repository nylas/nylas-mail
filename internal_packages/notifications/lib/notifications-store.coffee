_ = require 'underscore'
{Actions} = require 'nylas-exports'
NylasStore = require 'nylas-store'

VERBOSE = false
DISPLAY_TIME = 3000 # in ms

uuid_count = 0

class Notification
  constructor: ({@message, @type, @tag, @sticky, @actions, @icon} = {}) ->
    # Check to make sure the provided data is a valid notificaiton, since
    # notifications may be constructed by anyone developing on N1
    throw new Error "No `new` keyword when constructing Notification" unless @ instanceof Notification
    throw new Error "Type must be `info`, `developer`, `error`, or `success`" unless @type in ['info', 'error', 'success', 'developer']
    throw new Error "Message must be provided for notification" unless @message
    if @actions
      for action in @actions
        throw new Error "Actions must have an `label`" unless action['label']
        throw new Error "Actions must have an `id`" unless action['id']

    @tag ?= uuid_count++
    @creation = Date.now()
    @sticky ?= false
    unless @sticky
      @expiry = @creation + DISPLAY_TIME

    console.log "Created new notif with #{@tag}: #{@message}" if VERBOSE
    @

  valid: ->
    @sticky or @expiry > Date.now()

  toString: ->
    "Notification.#{@constructor.name}(#{@tag})"

class NotificationStore extends NylasStore
  constructor: ->
    @_flush()

    # The notification store listens for user interaction with notififcations
    # and just removes the notifications. To implement notification actions,
    # your package should listen to notificationActionTaken and check the
    # notification and action objects.
    @listenTo Actions.notificationActionTaken, ({notification, action}) =>
      @_removeNotification(notification) if action.dismisses
    @listenTo Actions.postNotification, (data) =>
      @_postNotification(new Notification(data))
    @listenTo Actions.dismissNotificationsMatching, (criteria) =>
      for tag, notif of @_notifications
        if _.isMatch(notif, criteria)
          delete @_notifications[tag]
      @trigger()

  ######### PUBLIC #######################################################

  notifications: =>
    console.log(JSON.stringify(@_notifications)) if VERBOSE
    sorted = _.sortBy(_.values(@_notifications), (n) -> -1*(n.creation + n.tag))
    _.reject sorted, (n) -> n.sticky

  stickyNotifications: =>
    console.log(JSON.stringify(@_notifications)) if VERBOSE
    sorted = _.sortBy(_.values(@_notifications), (n) -> -1*(n.creation + n.tag))
    _.filter sorted, (n) -> n.sticky

  Notification: Notification

  ########### PRIVATE ####################################################

  _flush: =>
    @_notifications = {}

  _postNotification: (notification) =>
    console.log "Queue Notification.#{notification}" if VERBOSE
    @_notifications[notification.tag] = notification
    if notification.expiry?
      timeoutVal = Math.max(0, notification.expiry - Date.now())
      timeoutId = setTimeout =>
        @_removeNotification(notification)
      , timeoutVal
      notification.timeoutId = timeoutId

    @trigger()

  # Returns a function for removing a particular notification. See usage
  # above in setTimeout()
  _removeNotification: (notification) =>
    console.log "Removed #{notification}" if VERBOSE

    clearTimeout(notification.timeoutId) if notification.timeoutId

    delete @_notifications[notification.tag]
    @trigger()

  # If the window matches the given context then we can show a
  # notification.
  _inWindowContext: (context={}) =>
    return true

module.exports = new NotificationStore()

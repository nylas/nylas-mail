_ = require 'underscore-plus'
Reflux = require 'reflux'
{Actions} = require 'inbox-exports'

VERBOSE = false
DISPLAY_TIME = 3000 # in ms

uuid_count = 0

class Notification
  constructor: ({@message, @type, @sticky, @actions, @icon} = {}) ->
    # Check to make sure the provided data is a valid notificaiton, since
    # notifications may be constructed by anyone developing on Edgehill
    throw new Error "No `new` keyword when constructing Notification" unless @ instanceof Notification
    throw new Error "Type must be `info`,`error`, or `success`" unless @type in ['info', 'error', 'success']
    throw new Error "Message must be provided for notification" unless @message
    if @actions
      for action in @actions
        throw new Error "Actions must have an `label`" unless action['label']
        throw new Error "Actions must have an `id`" unless action['id']

    @id = uuid_count++
    @creation = Date.now()
    @sticky ?= false
    unless @sticky
      @expiry = @creation + DISPLAY_TIME

    console.log "Created new notif with #{@id}: #{@message}" if VERBOSE
    @

  valid: ->
    @sticky or @expiry > Date.now()

  toString: ->
    "Notification.#{@constructor.name}(#{@id})"

module.exports =
NotificationStore = Reflux.createStore
  init: ->
    @_flush()

    # The notification store listens for user interaction with notififcations
    # and just removes the notifications. To implement notification actions,
    # your package should listen to notificationActionTaken and check the
    # notification and action objects.
    @listenTo Actions.notificationActionTaken, ({notification, action}) =>
      @_removeNotification(notification)()
    @listenTo Actions.postNotification, (data) =>
      @_postNotification(new Notification(data))
    @listenTo Actions.multiWindowNotification, (data={}, context={}) =>
      @_postNotification(new Notification(data)) if @_inWindowContext(context)
 
  ######### PUBLIC #######################################################

  notifications: ->
    console.log(JSON.stringify(@_notifications)) if VERBOSE
    sorted = _.sortBy(_.values(@_notifications), (n) -> -1*(n.creation + n.id))
    _.reject sorted, (n) -> n.sticky

  stickyNotifications: ->
    console.log(JSON.stringify(@_notifications)) if VERBOSE
    sorted = _.sortBy(_.values(@_notifications), (n) -> -1*(n.creation + n.id))
    _.filter sorted, (n) -> n.sticky

  Notification: Notification

  ########### PRIVATE ####################################################

  _flush: ->
    @_notifications = {}

  _postNotification: (notification) ->
    console.log "Queue Notification.#{notification}" if VERBOSE
    @_notifications[notification.id] = notification
    if notification.expiry?
      timeoutVal = Math.max(0, notification.expiry - Date.now())
      setTimeout(@_removeNotification(notification), timeoutVal)

    @trigger()

  # Returns a function for removing a particular notification. See usage
  # above in setTimeout()
  _removeNotification: (notification) -> =>
    console.log "Removed #{notification}" if VERBOSE
    delete @_notifications[notification.id]
    @trigger()

  # If the window matches the given context then we can show a
  # notification.
  _inWindowContext: (context={}) ->
    return true

React = require 'react'
NotificationStore = require '../notifications-store'
NotificationsItem = require './notifications-item'

class NotificationsHeader extends React.Component
  @displayName: "NotificationsHeader"

  @containerRequired: false

  constructor: (@props) ->
    @state = @_getStateFromStores()

  _getStateFromStores: =>
    items: NotificationStore.stickyNotifications()

  _onDataChanged: =>
    @setState @_getStateFromStores()

  componentDidMount: =>
    @_unlistener = NotificationStore.listen(@_onDataChanged, @)
    @

  # It's important that every React class explicitly stops listening to
  # N1 events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    @_unlistener() if @_unlistener
    @

  render: =>
    <div className="notifications-sticky">
      {@_notificationComponents()}
    </div>

  _notificationComponents: =>
    @state.items.map (notif) ->
      <NotificationsItem notification={notif} key={notif.message} />


module.exports = NotificationsHeader

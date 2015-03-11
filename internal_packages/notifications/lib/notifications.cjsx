React = require 'react'
NotificationStore = require './notifications-store'

module.exports =
Notifications = React.createClass

  getInitialState: ->
    notifications: NotificationStore.notifications()

  componentDidMount: ->
    @unsubscribeStore = NotificationStore.listen @_onStoreChange

  componentWillUnmount: ->
    @unsubscribeStore() if @unsubscribeStore

  render: ->
    <div className="notifications-momentary">
      {@_notificationComponents()}
    </div>

  _notificationComponents: ->
    @state.notifications.map (notification) ->
      <div key={notification.id}
           className={"notification-item notification-#{notification.type}"}>
        {notification.message}
      </div>

  _onStoreChange: ->
    @setState
      notifications: NotificationStore.notifications()

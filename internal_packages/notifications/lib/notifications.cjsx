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
    <div className="notifications">{
      for notification in @state.notifications
        <div className={"notification-item notification-#{notification.type}"}>
          {notification.message}
        </div>
    }</div>

  _onStoreChange: ->
    @setState
      notifications: NotificationStore.notifications()

React = require 'react'
{Actions} = require 'inbox-exports'
NotificationStore = require './notifications-store'

class NotificationStickyItem extends React.Component
  @displayName: "NotificationStickyItem"

  render: =>
    notif = @props.notification
    iconClass = if notif.icon then "fa #{notif.icon}" else ""
    actionComponents = notif.actions?.map (action) =>
      <a className="action" onClick={=> @_fireItemAction(notif, action)}>{action.label}</a>

    <div className={"notifications-sticky-item notification-#{notif.type}"}>
      <i className={iconClass}></i><span>{notif.message}</span>{actionComponents}
    </div>

  _fireItemAction: (notification, action) =>
    Actions.notificationActionTaken({notification, action})


class NotificationStickyBar extends React.Component
  @displayName: "NotificationStickyBar"

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
  # atom events before it unmounts. Thank you event-kit
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
      <NotificationStickyItem notification={notif} />





module.exports = NotificationStickyBar

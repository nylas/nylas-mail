React = require 'react'
{Actions} = require 'nylas-exports'
NotificationStore = require './notifications-store'

class NotificationStickyItem extends React.Component
  @displayName: "NotificationStickyItem"

  render: =>
    notif = @props.notification
    iconClass = if notif.icon then "fa #{notif.icon}" else ""
    actionDefault = null
    actionComponents = notif.actions?.map (action) =>
      classname = "action "
      if action.default
        actionDefault = action
        classname += "default"

      actionClick = (event) =>
        @_fireItemAction(notif, action)
        event.stopPropagation()
        event.preventDefault()

      <a className={classname} key={action.label} onClick={actionClick}>
         {action.label}
      </a>

    if actionDefault
      <div className={"notifications-sticky-item notification-#{notif.type} has-default-action"}
           onClick={=> @_fireItemAction(notif, actionDefault)}>
        <i className={iconClass}></i><div>{notif.message}</div>{actionComponents}
      </div>
    else
      <div className={"notifications-sticky-item notification-#{notif.type}"}>
        <i className={iconClass}></i><div>{notif.message}</div>{actionComponents}
      </div>

  _fireItemAction: (notification, action) =>
    Actions.notificationActionTaken({notification, action})


class NotificationStickyBar extends React.Component
  @displayName: "NotificationsStickyBar"

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
      <NotificationStickyItem notification={notif} key={notif.message} />


module.exports = NotificationStickyBar

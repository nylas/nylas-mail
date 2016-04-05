React = require 'react'
{Actions} = require 'nylas-exports'

class NotificationsItem extends React.Component
  @displayName: "NotificationsItem"

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
        <i className={iconClass}></i><div className="message">{notif.message}</div>{actionComponents}
      </div>
    else
      <div className={"notifications-sticky-item notification-#{notif.type}"}>
        <i className={iconClass}></i><div className="message">{notif.message}</div>{actionComponents}
      </div>

  _fireItemAction: (notification, action) =>
    Actions.notificationActionTaken({notification, action})

module.exports = NotificationsItem

React = require 'react'
_ = require 'underscore-plus'
classNames = require 'classnames'
{Actions, Utils, WorkspaceStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

class AccountSidebarSheetItem extends React.Component
  @displayName: 'AccountSidebarSheetItem'

  render: =>
    classSet = classNames
      'item': true
      'selected': @props.select

    if @props.item.icon and @props.item.icon.displayName?
      component = @props.item.icon
      icon = <component selected={@props.select} />

    else if _.isString(@props.item.icon)
      icon = <RetinaImg name={@props.item.icon} fallback="folder.png" colorfill={@props.select} />

    else
      icon = <RetinaImg name={"folder.png"} colorfill={@props.select} />

    <div className={classSet} onClick={@_onClick}>
      {icon}
      <span className="name"> {@props.item.name}</span>
    </div>

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(@props.item)


module.exports = AccountSidebarSheetItem

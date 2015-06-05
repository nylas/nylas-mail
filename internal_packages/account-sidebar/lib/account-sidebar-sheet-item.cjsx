React = require 'react'
_ = require 'underscore'
classNames = require 'classnames'
{Actions, Utils, WorkspaceStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

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
      icon = <RetinaImg name={@props.item.icon} fallback="folder.png" mode={RetinaImg.Mode.ContentIsMask} />

    else
      icon = <RetinaImg name={"folder.png"} mode={RetinaImg.Mode.ContentIsMask} />

    <div className={classSet} onClick={@_onClick}>
      {icon}
      <span className="name"> {@props.item.name}</span>
    </div>

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(@props.item)


module.exports = AccountSidebarSheetItem

React = require 'react'
{Actions, Utils, WorkspaceStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

module.exports =
AccountSidebarSheetItem = React.createClass
  displayName: 'AccountSidebarSheetItem'

  render: ->
    classSet =  React.addons.classSet
      'item': true
      'selected': @props.select

    <div className={classSet} onClick={@_onClick}>
      <RetinaImg name={"folder.png"} colorfill={@props.select} />
      <span className="name"> {@props.item.name}</span>
    </div>

  _onClick: (event) ->
    event.preventDefault()
    Actions.selectRootSheet(@props.item)

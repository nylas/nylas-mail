React = require 'react'
classNames = require 'classnames'
{Actions, Utils, UnreadCountStore, WorkspaceStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class AccountSidebarCategoryItem extends React.Component
  @displayName: 'AccountSidebarCategoryItem'

  constructor: (@props) ->
    @state =
      unreadCount: UnreadCountStore.count() ? 0

  componentWillMount: =>
    @_usub = UnreadCountStore.listen @_onUnreadCountChange

  componentWillUnmount: =>
    @_usub()

  _onUnreadCountChange: =>
    @setState unreadCount: UnreadCountStore.count()

  shouldComponentUpdate: (nextProps) =>
    @props?.item.name isnt nextProps.item.name or
    @props?.select isnt nextProps.select

  render: =>
    unread = []
    if @props.item.name is "inbox" and @state.unreadCount > 0
      unread = <div className="unread item-count-box">{@state.unreadCount}</div>

    containerClass = classNames
      'item': true
      'selected': @props.select

    <div className={containerClass} onClick={@_onClick} id={@props.item.id}>
      {unread}
      <RetinaImg name={"#{@props.item.name}.png"} fallback={'folder.png'} mode={RetinaImg.Mode.ContentIsMask} />
      <span className="name"> {@props.item.displayName}</span>
    </div>

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.focusCategory(@props.item)

module.exports = AccountSidebarCategoryItem

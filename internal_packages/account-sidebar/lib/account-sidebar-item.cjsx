React                      = require 'react'
{WorkspaceStore}           = require 'nylas-exports'
SidebarSheetItem           = require './account-sidebar-sheet-item'
AccountSidebarMailViewItem = require './account-sidebar-mail-view-item'
{DisclosureTriangle}       = require 'nylas-component-kit'


class AccountSidebarItem extends React.Component
  @displayName: "AccountSidebarItem"

  @propTypes: {
    item: React.PropTypes.object.isRequired
    onToggleCollapsed: React.PropTypes.func.isRequired
    selected: React.PropTypes.object
    collapsed: React.PropTypes.bool
    onDestroyItem: React.PropTypes.func
  }

  @defaultProps: {
    collapsed: false
  }

  componentDidMount: ->
    if @props.onDestroyItem?
      React.findDOMNode(@).addEventListener('contextmenu', @_onShowContextMenu)

  componentWillUnmount: ->
    if @props.onDestroyItem?
      React.findDOMNode(@).removeEventListener('contextmenu', @_onShowContextMenu)

  _itemComponent: (item) ->
    unless item instanceof WorkspaceStore.SidebarItem
      throw new Error("AccountSidebar:_itemComponents: sections contained an \
                       item which was not a SidebarItem")
    if item.component
      Component = item.component
      <Component
        item={item}
        select={item.id is @props.selected?.id } />

    else if item.mailViewFilter
      <AccountSidebarMailViewItem
        item={item}
        mailView={item.mailViewFilter}
        select={item.mailViewFilter.isEqual(@props.selected)} />

    else if item.sheet
      <SidebarSheetItem
        item={item}
        select={item.sheet.id is @props.selected?.id} />

    else
      throw new Error("AccountSidebarItem: each item must have a \
                       custom component, or a sheet or mailViewFilter")

  _onShowContextMenu: =>
    item = @props.item
    label = item.name
    {remote} = require 'electron'
    {Menu, MenuItem} = remote.require 'electron'

    menu = new Menu()
    menu.append(new MenuItem({
      label: "Delete #{label}"
      click: => @props.onDestroyItem?(item)
    }))
    menu.popup(remote.getCurrentWindow())

  render: ->
    item = @props.item
    <span  className="item-container">
      <DisclosureTriangle
        collapsed={@props.collapsed}
        visible={item.children.length > 0}
        onToggleCollapsed={ => @props.onToggleCollapsed(item.id)} />
      {@_itemComponent(item)}
    </span>

module.exports = AccountSidebarItem

React = require 'react'
_ = require 'underscore'
{Actions, MailViewFilter, WorkspaceStore, ThreadCountsStore} = require("nylas-exports")
{ScrollRegion, Flexbox} = require("nylas-component-kit")
SidebarDividerItem = require("./account-sidebar-divider-item")
SidebarSheetItem = require("./account-sidebar-sheet-item")
AccountSidebarStore = require ("./account-sidebar-store")
AccountSidebarMailViewItem = require("./account-sidebar-mail-view-item")
{RetinaImg} = require 'nylas-component-kit'

class DisclosureTriangle extends React.Component
  @displayName: 'DisclosureTriangle'

  @propTypes:
    collapsed: React.PropTypes.bool
    visible: React.PropTypes.bool
    onToggleCollapsed: React.PropTypes.func.isRequired

  render: ->
    classnames = "disclosure-triangle"
    classnames += " visible" if @props.visible
    classnames += " collapsed" if @props.collapsed
    <div className={classnames} onClick={@props.onToggleCollapsed}><div></div></div>


class AccountSidebar extends React.Component
  @displayName: 'AccountSidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 210

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @state.collapsed = NylasEnv.config.get('core.accountSidebarCollapsed') ? {}

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push AccountSidebarStore.listen @_onStoreChange
    @unsubscribers.push ThreadCountsStore.listen @_onStoreChange
    @configSubscription = NylasEnv.config.observe('core.workspace.showUnreadForAllCategories', @_onStoreChange)

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers
    @configSubscription?.dispose()

  render: =>
    <ScrollRegion style={flex:1} id="account-sidebar">
      <div className="account-sidebar-sections">
        {@_sections()}
      </div>
    </ScrollRegion>

  _sections: =>
    @state.sections.map (section) =>
      <section key={section.label}>
        <div className="heading">{section.label}</div>
        {@_itemComponents(section.items)}
      </section>

  _itemComponents: (items) =>
    components = []

    items.forEach (item) =>
      components.push(
        <span key={item.id} className="item-container">
          <DisclosureTriangle
            collapsed={@state.collapsed[item.id]}
            visible={item.children.length > 0}
            onToggleCollapsed={ => @_onToggleCollapsed(item.id)}/>
          {@_itemComponent(item)}
        </span>
      )

      if item.children.length and not @state.collapsed[item.id]
        components.push(
          <section key={"#{item.id}-children"}>
            {@_itemComponents(item.children)}
          </section>
        )

    components

  _itemUnreadCount: (item) =>
    category = item.mailViewFilter.category
    if category and (category.name is 'inbox' or @state.unreadCountsForAll)
      return @state.unreadCounts[category.id]
    return 0

  _itemComponent: (item) =>
    unless item instanceof WorkspaceStore.SidebarItem
      throw new Error("AccountSidebar:_itemComponents: sections contained an \
                       item which was not a SidebarItem")

    if item.component
      Component = item.component
      <Component
        item={item}
        select={item.id is @state.selected?.id } />

    else if item.mailViewFilter
      <AccountSidebarMailViewItem
        item={item}
        itemUnreadCount={@_itemUnreadCount(item)}
        mailView={item.mailViewFilter}
        select={item.mailViewFilter.isEqual(@state.selected)} />

    else if item.sheet
      <SidebarSheetItem
        item={item}
        select={item.sheet.id is @state.selected?.id} />

    else
      throw new Error("AccountSidebar:_itemComponents: each item must have a \
                       custom component, or a sheet or mailViewFilter")

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _onToggleCollapsed: (itemId) =>
    collapsed = _.clone(@state.collapsed)
    collapsed[itemId] = !collapsed[itemId]
    NylasEnv.config.set('core.accountSidebarCollapsed', collapsed)
    @setState({collapsed})

  _getStateFromStores: =>
    sections: AccountSidebarStore.sections()
    selected: AccountSidebarStore.selected()
    unreadCounts: ThreadCountsStore.unreadCounts()
    unreadCountsForAll: NylasEnv.config.get('core.workspace.showUnreadForAllCategories')


module.exports = AccountSidebar

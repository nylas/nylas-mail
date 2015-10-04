React = require 'react'
{Actions, MailViewFilter, WorkspaceStore} = require("nylas-exports")
{ScrollRegion} = require("nylas-component-kit")
SidebarDividerItem = require("./account-sidebar-divider-item")
SidebarSheetItem = require("./account-sidebar-sheet-item")
AccountSwitcher = require ("./account-switcher")
AccountSidebarStore = require ("./account-sidebar-store")
AccountSidebarMailViewItem = require("./account-sidebar-mail-view-item")
{RetinaImg} = require 'nylas-component-kit'

class AccountSidebar extends React.Component
  @displayName: 'AccountSidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 210

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push AccountSidebarStore.listen @_onStoreChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    <ScrollRegion style={flex:1} id="account-sidebar">
      <AccountSwitcher />
      <div className="account-sidebar-sections">
        {@_sections()}
      </div>
    </ScrollRegion>

  _sections: =>
    @state.sections.map (section) =>
      <section key={section.label}>
        <div className="heading">{section.label}</div>
        {@_itemComponents(section)}
      </section>

  _itemComponents: (section) =>
    section.items.map (item) =>
      unless item instanceof WorkspaceStore.SidebarItem
        throw new Error("AccountSidebar:_itemComponents: sections contained an \
                         item which was not a SidebarItem")

      if item.component
        Component = item.component
        <Component
          key={item.id}
          item={item}
          select={item.id is @state.selected?.id } />

      else if item.mailViewFilter
        <AccountSidebarMailViewItem
          key={item.id}
          mailView={item.mailViewFilter}
          select={item.mailViewFilter.isEqual(@state.selected)} />

      else if item.sheet
        <SidebarSheetItem
          key={item.id}
          item={item}
          select={item.sheet.id is @state.selected?.id} />

      else
        throw new Error("AccountSidebar:_itemComponents: each item must have a \
                         custom component, or a sheet or mailViewFilter")

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: =>
    sections: AccountSidebarStore.sections()
    selected: AccountSidebarStore.selected()


module.exports = AccountSidebar

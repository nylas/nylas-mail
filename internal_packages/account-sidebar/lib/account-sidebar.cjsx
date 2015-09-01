React = require 'react'
{Actions, Category} = require("nylas-exports")
{ScrollRegion} = require("nylas-component-kit")
SidebarDividerItem = require("./account-sidebar-divider-item")
SidebarSheetItem = require("./account-sidebar-sheet-item")
AccountSidebarStore = require ("./account-sidebar-store")
AccountSidebarCategoryItem = require("./account-sidebar-category-item")

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

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    <ScrollRegion style={flex:1} id="account-sidebar">
      <div className="account-sidebar-sections">
        {@_sections()}
      </div>
    </ScrollRegion>

  _sections: =>
    return @state.sections.map (section) =>
      <section key={section.label}>
        <div className="heading">{section.label}</div>
        {@_itemComponents(section)}
      </section>

  _itemComponents: (section) =>
    section.items?.map (item) =>
      return unless item
      if item instanceof Category
        itemClass = AccountSidebarCategoryItem
      else if item.sidebarComponent
        itemClass = item.sidebarComponent
      else
        itemClass = SidebarSheetItem

      <itemClass
        key={item.id ? item.type}
        item={item}
        sectionType={section.type}
        select={item.id is @state.selected?.id }/>

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _onSwitchAccount: (account) =>
    Actions.selectAccountId(account.id)

  _getStateFromStores: =>
    sections: AccountSidebarStore.sections()
    selected: AccountSidebarStore.selected()


module.exports = AccountSidebar

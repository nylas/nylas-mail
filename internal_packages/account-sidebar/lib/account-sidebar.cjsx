React = require 'react'
{Actions} = require("nylas-exports")
SidebarDividerItem = require("./account-sidebar-divider-item")
SidebarTagItem = require("./account-sidebar-tag-item")
SidebarSheetItem = require("./account-sidebar-sheet-item")
SidebarStore = require ("./account-sidebar-store")

class AccountSidebar extends React.Component
  @displayName: 'AccountSidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 190

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribe = SidebarStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    @unsubscribe() if @unsubscribe

  render: =>
    <div id="account-sidebar" className="account-sidebar">
      <div className="account-sidebar-sections">
        {@_sections()}
      </div>
    </div>

  _sections: =>
    return @state.sections.map (section) =>
      <section key={section.label}>
        <div className="heading">{section.label}</div>
        {@_itemComponents(section)}
      </section>

  _itemComponents: (section) =>
    if section.type is 'tag'
      itemClass = SidebarTagItem
    else if section.type is 'sheet'
      itemClass = SidebarSheetItem
    else
      throw new Error("Unsure how to render item type #{section.type}")

    section.items?.map (item) =>
      <itemClass
        key={item.id ? item.type}
        item={item}
        select={item.id is @state.selected?.id }/>

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: =>
    sections: SidebarStore.sections()
    selected: SidebarStore.selected()


module.exports = AccountSidebar

React = require 'react'
{Actions} = require("inbox-exports")
SidebarDividerItem = require("./account-sidebar-divider-item.cjsx")
SidebarTagItem = require("./account-sidebar-tag-item.cjsx")
SidebarStore = require ("./account-sidebar-store")

module.exports =
AccountSidebar = React.createClass

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribe = SidebarStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    <div className="account-sidebar-sections">
      {@_sections()}
    </div>

  _sections: ->
    return @state.sections.map (section) =>
      <section>
        {@_itemComponents(section)}
      </section>

  _itemComponents: (section) ->
    return section.tags?.map (tag) =>
      <SidebarTagItem
        key={tag.id}
        tag={tag}
        select={tag?.id == @state?.selected}/>

  _onStoreChange: ->
    @setState @_getStateFromStores()
    if not SidebarStore.selectedId()?
      Actions.selectTagId("inbox")

  _getStateFromStores: ->
    sections: SidebarStore.sections()
    selected: SidebarStore.selectedId()


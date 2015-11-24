React = require 'react'
_ = require 'underscore'
{ScrollRegion} = require 'nylas-component-kit'
AccountSidebarStore = require './account-sidebar-store'
AccountSidebarSection = require './account-sidebar-section'


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

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    <ScrollRegion style={flex:1} id="account-sidebar">
      <div className="account-sidebar-sections">
        {@_sections()}
      </div>
    </ScrollRegion>

  _sections: =>
    @state.sections.map (section) =>
      <AccountSidebarSection
        key={section.label}
        section={section}
        collapsed={@state.collapsed}
        selected={@state.selected}
        onToggleCollapsed={@_onToggleCollapsed} />
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

module.exports = AccountSidebar

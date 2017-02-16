_ = require 'underscore'
React = require 'react'
{Utils, AccountStore} = require 'nylas-exports'
{OutlineView, ScrollRegion, Flexbox} = require 'nylas-component-kit'
AccountSwitcher = require './account-switcher'
SidebarStore = require '../sidebar-store'


class AccountSidebar extends React.Component
  @displayName: 'AccountSidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 250

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push SidebarStore.listen @_onStoreChange
    @unsubscribers.push AccountStore.listen @_onStoreChange

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: =>
    accounts: AccountStore.accounts()
    sidebarAccountIds: SidebarStore.sidebarAccountIds()
    userSections: SidebarStore.userSections()
    standardSection: SidebarStore.standardSection()

  _renderUserSections: (sections) =>
    sections.map (section) =>
      <OutlineView key={section.title} {...section} />

  render: =>
    {accounts, sidebarAccountIds, userSections, standardSection} = @state

    <Flexbox direction="column" style={order: 0, flexShrink: 1, flex: 1}>
      <ScrollRegion className="account-sidebar" style={order: 2}>
        <AccountSwitcher accounts={accounts} sidebarAccountIds={sidebarAccountIds} />
        <div className="account-sidebar-sections">
          <OutlineView {...standardSection} />
          {@_renderUserSections(userSections)}
        </div>
      </ScrollRegion>
    </Flexbox>


module.exports = AccountSidebar

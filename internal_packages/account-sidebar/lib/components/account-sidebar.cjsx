_ = require 'underscore'
React = require 'react'
{OutlineView, ScrollRegion} = require 'nylas-component-kit'
SidebarStore = require '../sidebar-store'


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
    @unsubscribers.push SidebarStore.listen @_onStoreChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: =>
    standardSection: SidebarStore.standardSection()
    userSections: SidebarStore.userSections()

  _renderUserSections: (sections) =>
    sections.map (section) =>
      <OutlineView key={section.title} {...section} />

  render: =>
    standardSection = @state.standardSection
    userSections = @state.userSections

    <ScrollRegion className="account-sidebar" >
      <div className="account-sidebar-sections">
        <OutlineView {...standardSection} />
        {@_renderUserSections(userSections)}
      </div>
    </ScrollRegion>


module.exports = AccountSidebar

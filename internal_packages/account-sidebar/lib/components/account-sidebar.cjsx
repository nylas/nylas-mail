_ = require 'underscore'
React = require 'react'
{OutlineView, ScrollRegion} = require 'nylas-component-kit'
AccountSidebarStore = require '../account-sidebar-store'


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

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: =>
    sections: [
      AccountSidebarStore.mailboxesSection()
      AccountSidebarStore.categoriesSection()
    ]

  _renderSections: =>
    @state.sections.map (section) =>
      <OutlineView key={section.label} {...section} />

  render: =>
    <ScrollRegion className="account-sidebar" >
      <div className="account-sidebar-sections">
        {@_renderSections()}
      </div>
    </ScrollRegion>


module.exports = AccountSidebar

React = require 'react'
Immutable = require 'immutable'
_ = require 'underscore'
classNames = require 'classnames'
{RetinaImg, Flexbox, DisclosureTriangle} = require 'nylas-component-kit'
{Actions, AccountStore} = require 'nylas-exports'
{PreferencesUIStore} = require 'nylas-exports'

class PreferencesSidebarItem extends React.Component
  @displayName: 'PreferencesSidebarItem'
  @propTypes:
    accounts: React.PropTypes.array
    selection: React.PropTypes.instanceOf(Immutable.Map).isRequired
    tabItem: React.PropTypes.instanceOf(PreferencesUIStore.TabItem).isRequired

  constructor: ->
    @state =
      collapsed: true

  render: =>
    {tabId, displayName, componentRequiresAccount} = @props.tabItem

    subitems = @_renderSubitems()
    subitemsComponent = <ul className="subitems">{subitems}</ul>
    if @state.collapsed
      subitemsComponent = false

    classes = classNames
      "item": true
      "active": tabId is @props.selection.get('tabId')
      "has-subitems": subitems isnt false

    <div key={tabId} className={classes} onClick={@_onClick}>
      <DisclosureTriangle
        collapsed={@state.collapsed}
        visible={subitems isnt false}
        onToggleCollapsed={@_onClick} />
      <div className="name">{displayName}</div>
      {subitemsComponent}
    </div>

  _renderSubitems: =>
    if @props.tabItem.componentRequiresAccount
      @props.accounts.map (account) =>
        classes = classNames
          "subitem": true
          "active": account.id is @props.selection.get('accountId')

        <li key={account.id}
            className={classes}
            onClick={ (event) => @_onClickAccount(event, account.id)}>
          {account.emailAddress}
        </li>
    else
      return false

  _onClick: =>
    if @props.tabItem.componentRequiresAccount
      @setState(collapsed: !@state.collapsed)
    else
      Actions.switchPreferencesTab(@props.tabItem.tabId)

  _onClickAccount: (event, accountId) =>
    Actions.switchPreferencesTab(@props.tabItem.tabId, {accountId})
    event.stopPropagation()


class PreferencesSidebar extends React.Component
  @displayName: 'PreferencesSidebar'

  @propTypes:
    tabs: React.PropTypes.instanceOf(Immutable.List).isRequired
    selection: React.PropTypes.instanceOf(Immutable.Map).isRequired

  constructor: ->
    @state =
      accounts: AccountStore.items()

  componentDidMount: =>
    @unsub = AccountStore.listen @_onAccountsChanged

  componentWillUnmount: =>
    @unsub?()

  render: =>
    <div className="preferences-sidebar">
      { @props.tabs.map (tabItem) =>
        <PreferencesSidebarItem
          tabItem={tabItem}
          accounts={@state.accounts}
          selection={@props.selection} />
      }
    </div>

  _onAccountsChanged: =>
    @setState(accounts: AccountStore.items())

module.exports = PreferencesSidebar

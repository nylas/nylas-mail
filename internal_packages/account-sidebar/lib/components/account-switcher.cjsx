React = require 'react'
crypto = require 'crypto'
classNames = require 'classnames'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'
SidebarActions = require '../sidebar-actions'


ItemTypes = {
  "Unified"
}

class AccountSwitcher extends React.Component
  @displayName: 'AccountSwitcher'

  @propTypes:
    accounts: React.PropTypes.array.isRequired
    focusedAccounts: React.PropTypes.array.isRequired

  # Helpers

  _makeAccountItem: (account) =>
    {id, label, emailAddress, provider} = account
    email = emailAddress
    iconName = provider
    accounts = [account]
    return {id, label, email, iconName, accounts}

  _makeUnifiedItem: =>
    id = ItemTypes.Unified
    label = "All Accounts"
    email = ""
    iconName = 'unified'
    accounts = @props.accounts
    return {id, label, email, iconName, accounts}


  _selectedItem: =>
    if @props.focusedAccounts.length > 1
      @_makeUnifiedItem()
    else
      @_makeAccountItem(@props.focusedAccounts[0])

  _toggleDropdown: =>
    @setState showing: !@state.showing

  _makeMenuItem: (item, idx) =>
    menuItem = {
      label: item.label,
      click: @_onSwitchAccount.bind(@, item)
      accelerator: "CmdOrCtrl+#{idx}"
    }

    if @_selectedItem().id is item.id
      menuItem.type = 'checkbox'
      menuItem.checked = true

    return menuItem

  _makeMenuTemplate: =>
    template = []
    items = @props.accounts.map(@_makeAccountItem)

    if @props.accounts.length > 1
      unifiedItem = @_makeUnifiedItem()
      template = [
        @_makeMenuItem(unifiedItem, 1)
        {type: 'separator'}
      ]

    items.forEach (item, idx) => template.push(@_makeMenuItem(item, idx + 2))

    template = template.concat [
      {type: 'separator'}
      {label: 'Manage Accounts...', click: @_onManageAccounts}
    ]
    return template


  # Handlers

  _onSwitchAccount: (item) =>
    SidebarActions.focusAccounts(item.accounts)

  _onManageAccounts: =>
    Actions.switchPreferencesTab('Accounts')
    Actions.openPreferences()

  _onShowMenu: =>
    remote = require('electron').remote
    Menu = remote.Menu
    menu = Menu.buildFromTemplate(@_makeMenuTemplate())
    menu.popup()

  render: =>
    <div className="account-switcher" onMouseDown={@_onShowMenu}>
      <RetinaImg
        style={width: 13, height: 14}
        name="account-switcher-dropdown.png"
        mode={RetinaImg.Mode.ContentDark} />
    </div>


module.exports = AccountSwitcher

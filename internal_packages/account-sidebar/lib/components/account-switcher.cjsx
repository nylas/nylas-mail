React = require 'react'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'
AccountCommands = require '../account-commands'


class AccountSwitcher extends React.Component
  @displayName: 'AccountSwitcher'

  @propTypes:
    accounts: React.PropTypes.array.isRequired
    sidebarAccountIds: React.PropTypes.array.isRequired


  _makeMenuTemplate: =>
    template = AccountCommands.menuTemplate(
      @props.accounts,
      @props.sidebarAccountIds,
      clickHandlers: true
    )
    template = template.concat [
      {type: 'separator'}
      {label: 'Add Account...', click: @_onAddAccount}
      {label: 'Manage Accounts...', click: @_onManageAccounts}
    ]
    return template

  # Handlers

  _onAddAccount: =>
    ipc = require('electron').ipcRenderer
    ipc.send('command', 'application:add-account')

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

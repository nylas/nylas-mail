React = require 'react'
_ = require 'underscore'
{AccountStore, Actions} = require 'nylas-exports'
PreferencesAccountList = require './preferences-account-list'
PreferencesAccountDetails = require './preferences-account-details'

class PreferencesAccounts extends React.Component
  @displayName: 'PreferencesAccounts'

  constructor: (@props) ->
    @state = @getStateFromStores()
    @state.selected = @state.accounts[0]

  componentDidMount: =>
    @unsubscribe = AccountStore.listen @_onAccountsChanged

  componentWillUnmount: =>
    @unsubscribe?()

  getStateFromStores: =>
    accounts: AccountStore.items()

  _onAccountsChanged: =>
    @setState(@getStateFromStores())


  # Update account list actions
  #
  _onAddAccount: =>
    ipc = require('electron').ipcRenderer
    ipc.send('command', 'application:add-account')

  _onAccountSelected: (account) =>
    @setState(selected: account)

  _onRemoveAccount: (account) =>
    Actions.removeAccount(account.id)


  # Update account actions
  #
  _onAccountUpdated: (account, updates) =>
    Actions.updateAccount(account.id, updates)

  render: =>
    <section className="preferences-accounts">
      <h2>Accounts</h2>
      <div className="accounts-content">
        <PreferencesAccountList
          accounts={@state.accounts}
          onAddAccount={@_onAddAccount}
          onAccountSelected={@_onAccountSelected}
          onRemoveAccount={@_onRemoveAccount} />
        <PreferencesAccountDetails
          account={@state.selected}
          onAccountUpdated={@_onAccountUpdated} />
      </div>
    </section>

module.exports = PreferencesAccounts

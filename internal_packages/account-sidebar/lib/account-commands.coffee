_ = require 'underscore'
{AccountStore, MenuHelpers} = require 'nylas-exports'
SidebarActions = require './sidebar-actions'


class AccountCommands

  @_focusAccounts: (accounts) ->
    SidebarActions.focusAccounts(accounts)
    NylasEnv.show() unless NylasEnv.isVisible()

  @_isSelected: (account, focusedAccounts) =>
    if focusedAccounts.length > 1
      return account instanceof Array
    else if focusedAccounts.length is 1
      return account?.id is focusedAccounts[0].id
    else
      return false

  @registerCommands: (accounts) ->
    @_commandsDisposable?.dispose()
    commands = {}

    allKey = "application:select-account-0"
    commands[allKey] = @_focusAccounts.bind(@, accounts)

    [1..8].forEach (index) =>
      account = accounts[index - 1]
      return unless account
      key = "application:select-account-#{index}"
      commands[key] = @_focusAccounts.bind(@, [account])

    @_commandsDisposable = NylasEnv.commands.add('body', commands)

  @registerMenuItems: (accounts, focusedAccounts) ->
    windowMenu = _.find NylasEnv.menu.template, ({label}) ->
      MenuHelpers.normalizeLabel(label) is 'Window'
    return unless windowMenu

    submenu = _.reject windowMenu.submenu, (item) -> item.account
    return unless submenu

    idx = _.findIndex submenu, ({type}) -> type is 'separator'
    return unless idx > 0

    template = @menuTemplate(accounts, focusedAccounts)
    submenu.splice(idx + 1, 0, template...)
    windowMenu.submenu = submenu
    NylasEnv.menu.update()

  @menuItem: (account, idx, {isSelected, clickHandlers} = {}) =>
    item = {
      label: account.label ? "All Accounts",
      command: "application:select-account-#{idx}",
      account: true
    }
    if isSelected
      item.type = 'checkbox'
      item.checked = true
    if clickHandlers
      accounts = if account instanceof Array then account else [account]
      item.click = @_focusAccounts.bind(@, accounts)
      item.accelerator = "CmdOrCtrl+#{idx + 1}"
    return item

  @menuTemplate: (accounts, focusedAccounts, {clickHandlers} = {}) =>
    template = []
    multiAccount = accounts.length > 1

    if multiAccount
      isSelected = @_isSelected(accounts, focusedAccounts)
      template = [
        @menuItem(accounts, 0, {isSelected, clickHandlers})
      ]

    template = template.concat accounts.map((account, idx) =>
      # If there's only one account, it should be mapped to Cmd+1, not Cmd+2
      accIdx = if multiAccount then idx + 1 else idx
      isSelected = @_isSelected(account, focusedAccounts)
      return @menuItem(account, accIdx, {isSelected, clickHandlers})
    )
    return template

  @register: (accounts, focusedAccounts) ->
    @registerCommands(accounts)
    @registerMenuItems(accounts, focusedAccounts)


module.exports = AccountCommands

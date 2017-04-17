_ = require 'underscore'
{Actions, MenuHelpers} = require 'nylas-exports'


class AccountCommands

  @_focusAccounts: (accounts) ->
    Actions.focusDefaultMailboxPerspectiveForAccounts(accounts)
    NylasEnv.show() unless NylasEnv.isVisible()

  @_isSelected: (account, sidebarAccountIds) =>
    if sidebarAccountIds.length > 1
      return account instanceof Array
    else if sidebarAccountIds.length is 1
      return account?.id is sidebarAccountIds[0]
    else
      return false

  @registerCommands: (accounts) ->
    @_commandsDisposable?.dispose()
    commands = {}

    allKey = "window:select-account-0"
    commands[allKey] = @_focusAccounts.bind(@, accounts)

    [1..8].forEach (index) =>
      account = accounts[index - 1]
      return unless account
      key = "window:select-account-#{index}"
      commands[key] = @_focusAccounts.bind(@, [account])

    @_commandsDisposable = NylasEnv.commands.add(document.body, commands)

  @registerMenuItems: (accounts, sidebarAccountIds) ->
    windowMenu = _.find NylasEnv.menu.template, ({label}) ->
      MenuHelpers.normalizeLabel(label) is 'Window'
    return unless windowMenu

    submenu = _.reject windowMenu.submenu, (item) -> item.account
    return unless submenu

    idx = _.findIndex submenu, ({type}) -> type is 'separator'
    return unless idx > 0

    template = @menuTemplate(accounts, sidebarAccountIds)
    submenu.splice(idx + 1, 0, template...)
    windowMenu.submenu = submenu
    NylasEnv.menu.update()

  @menuItem: (account, idx, {isSelected, clickHandlers} = {}) =>
    item = {
      label: account.label ? "All Accounts",
      command: "window:select-account-#{idx}",
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

  @menuTemplate: (accounts, sidebarAccountIds, {clickHandlers} = {}) =>
    template = []
    multiAccount = accounts.length > 1

    if multiAccount
      isSelected = @_isSelected(accounts, sidebarAccountIds)
      template = [
        @menuItem(accounts, 0, {isSelected, clickHandlers})
      ]

    template = template.concat accounts.map((account, idx) =>
      # If there's only one account, it should be mapped to command+1, not command+2
      accIdx = if multiAccount then idx + 1 else idx
      isSelected = @_isSelected(account, sidebarAccountIds)
      return @menuItem(account, accIdx, {isSelected, clickHandlers})
    )
    return template

  @register: (accounts, sidebarAccountIds) ->
    @registerCommands(accounts)
    @registerMenuItems(accounts, sidebarAccountIds)


module.exports = AccountCommands

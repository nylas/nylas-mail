path = require 'path'

_ = require 'underscore'
fs = require 'fs-plus'
{ipcRenderer} = require 'electron'
{Disposable} = require 'event-kit'
Utils = require './flux/models/utils'

MenuHelpers = require './menu-helpers'

module.exports =
class MenuManager
  constructor: ({@resourcePath}) ->
    @template = []
    @loadPlatformItems()

    NylasEnv.keymaps.onDidReloadKeymap => @update()
    NylasEnv.commands.onRegistedCommandsChanged => @update()

  # Public: Adds the given items to the application menu.
  #
  # ## Examples
  #
  # ```coffee
  #   NylasEnv.menu.add [
  #     {
  #       label: 'Hello'
  #       submenu : [{label: 'World!', command: 'hello:world'}]
  #     }
  #   ]
  # ```
  #
  # * `items` An {Array} of menu item {Object}s containing the keys:
  #   * `label` The {String} menu label.
  #   * `submenu` An optional {Array} of sub menu items.
  #   * `command` An optional {String} command to trigger when the item is
  #     clicked.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # added menu items.
  add: (items) ->
    items = Utils.deepClone(items)
    @merge(@template, item) for item in items
    @update()
    new Disposable => @remove(items)

  remove: (items) ->
    @unmerge(@template, item) for item in items
    @update()

  # Public: Refreshes the currently visible menu.
  update: =>
    return if @pendingUpdateOperation
    @pendingUpdateOperation = true
    window.requestAnimationFrame =>
      @pendingUpdateOperation = false
      MenuHelpers.forEachMenuItem @template, (item) =>
        if item.command and item.command.startsWith('application:') is false
          item.enabled = NylasEnv.commands.listenerCountForCommand(item.command) > 0
        if item.submenu?
          item.enabled = not _.every item.submenu, (item) -> item.enabled is false
      @sendToBrowserProcess(@template, NylasEnv.keymaps.getBindingsForAllCommands())

  loadPlatformItems: ->
    menusDirPath = path.join(@resourcePath, 'menus')
    platformMenuPath = fs.resolve(menusDirPath, process.platform, ['json'])
    {menu} = require(platformMenuPath)
    @add(menu)

  # Merges an item in a submenu aware way such that new items are always
  # appended to the bottom of existing menus where possible.
  merge: (menu, item) ->
    MenuHelpers.merge(menu, item)

  unmerge: (menu, item) ->
    MenuHelpers.unmerge(menu, item)

  # OSX can't handle displaying accelerators for multiple keystrokes.
  # If they are sent across, it will stop processing accelerators for the rest
  # of the menu items.
  filterMultipleKeystroke: (keystrokesByCommand) ->
    filtered = {}
    for key, bindings of keystrokesByCommand
      for binding in bindings
        continue unless binding.indexOf(' ') is -1
        continue unless /(cmd|ctrl|shift|alt|mod)/.test(binding) or /f\d+/.test(binding)
        filtered[key] ?= []
        filtered[key].push(binding)
    filtered

  sendToBrowserProcess: (template, keystrokesByCommand) ->
    keystrokesByCommand = @filterMultipleKeystroke(keystrokesByCommand)
    ipcRenderer.send('update-application-menu', template, keystrokesByCommand)

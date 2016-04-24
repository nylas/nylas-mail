fs = require 'fs-plus'
path = require 'path'
mousetrap = require 'mousetrap'
{ipcRenderer} = require 'electron'
{Emitter, Disposable} = require 'event-kit'

###
By default, Mousetrap stops all hotkeys within text inputs. Override this to
more specifically block only hotkeys that have no modifier keys (things like
Gmail's "x", while allowing standard hotkeys.)
###
mousetrap.prototype.stopCallback = (e, element, combo, sequence) ->
  withinTextInput = element.tagName == 'INPUT' || element.tagName == 'SELECT' || element.tagName == 'TEXTAREA' || element.isContentEditable
  if withinTextInput
    return /(mod|shift|command|ctrl)/.test(combo) is false
  return false

class KeymapManager

  constructor: ({@configDirPath, @resourcePath}) ->
    @_emitter = new Emitter
    @_bindings = {}
    @_keystrokes = {}
    @_keymapDisposables = {}

  loadBundledKeymaps: ->
    # Load the base keymap and the base.platform keymap
    baseKeymap = fs.resolve(path.join(@resourcePath, 'keymaps', 'base.json'))
    basePlatformKeymap = fs.resolve(path.join(@resourcePath, 'keymaps', "base-#{process.platform}.json"))
    @loadKeymap(baseKeymap)
    @loadKeymap(basePlatformKeymap)

    # Load the template keymap (Gmail, Mail.app, etc.) the user has chosen
    templateConfigKey = 'core.keymapTemplate'
    templateKeymapPath = null
    reloadTemplateKeymap = =>
      @_keymapDisposables[templateKeymapPath].dispose() if templateKeymapPath
      templateFile = NylasEnv.config.get(templateConfigKey)?.replace("GoogleInbox", "Inbox by Gmail")
      if templateFile
        templateKeymapPath = fs.resolve(path.join(@resourcePath, 'keymaps', 'templates', "#{templateFile}.json"))
        if fs.existsSync(templateKeymapPath)
          @loadKeymap(templateKeymapPath)
        else
          console.warn("Could not find #{templateKeymapPath}")

    NylasEnv.config.observe(templateConfigKey, reloadTemplateKeymap)
    reloadTemplateKeymap()

  loadUserKeymap: ->
    userKeymapPath = path.join(@configDirPath, 'keymap.json')
    return unless fs.isFileSync(userKeymapPath)

    try
      @loadKeymap(userKeymapPath)
      fs.watch userKeymapPath, =>
        @_keymapDisposables[userKeymapPath].dispose()
        @loadKeymap(userKeymapPath)
    catch error
      message = """
        Unable to watch path: `#{path.basename(userKeymapPath)}`. Make sure you
        have permission to read `#{userKeymapPath}`.
      """
      console.error(message)

  loadKeymap: (path, keymaps = null) =>
    try
      keymaps ?= JSON.parse(fs.readFileSync(path))
    catch e
      return if e.code is 'ENOENT'
      throw e

    @forEachInKeymaps keymaps, (command, keystrokes) =>
      @ensureKeystrokesRegistered(keystrokes)
      @_keystrokes[keystrokes].push(command)
      @_bindings[command] ?= []
      @_bindings[command].push(keystrokes)

    @_emitter.emit('on-did-reload-keymap')

    disposable = new Disposable =>
      @forEachInKeymaps keymaps, (command, keystrokes) =>
        @_keystrokes[keystrokes] = @_keystrokes[keystrokes].filter (c) ->
          c isnt command
        @_bindings[command] = @_bindings[command].filter (k) ->
          k isnt keystrokes

    @_keymapDisposables[path] = disposable
    return disposable

  forEachInKeymaps: (keymaps, cb) =>
    Object.keys(keymaps).forEach (command) =>
      keystrokesArray = keymaps[command]
      keystrokesArray = [keystrokesArray] unless keystrokes instanceof Array
      for keystrokes in keystrokesArray
        cb(command, keystrokes)

  ensureKeystrokesRegistered: (keystrokes) =>
    return if @_keystrokes[keystrokes]
    @_keystrokes[keystrokes] = []
    Mousetrap.bind keystrokes, (event) =>
      for command in @_keystrokes[keystrokes]
        if command.startsWith('application:')
          ipcRenderer.send('command', command)
        else
          NylasEnv.commands.dispatch(command)
      return false

  onDidReloadKeymap: (callback) =>
    @_emitter.on('on-did-reload-keymap', callback)

  getBindingsForAllCommands: ->
    @_bindings

  getBindingsForCommand: (command) ->
    @_bindings[command] || []

module.exports = KeymapManager

fs = require 'fs-plus'
path = require 'path'
CSON = require 'season'
AtomKeymap = require 'atom-keymap'
KeymapUtils = require './keymap-utils'

class KeymapManager extends AtomKeymap

  constructor: ->
    super
    @subscribeToFileReadFailure()

  onDidLoadBundledKeymaps: (callback) ->
    @emitter.on 'did-load-bundled-keymaps', callback

  # N1 adds the `cmdctrl` extension. This will use `cmd` or `ctrl` on a
  # mac, and `ctrl` only on windows and linux.
  readKeymap: (args...) ->
    return KeymapUtils.cmdCtrlPreprocessor super(args...)

  loadBundledKeymaps: ->
    # Load the base keymap and the base.platform keymap
    baseKeymap = fs.resolve(path.join(@resourcePath, 'keymaps'), 'base', ['cson', 'json'])
    inputResetKeymap = fs.resolve(path.join(@resourcePath, 'keymaps'), 'input-reset', ['cson', 'json'])
    basePlatformKeymap = fs.resolve(path.join(@resourcePath, 'keymaps'), "base-#{process.platform}", ['cson', 'json'])
    @loadKeymap(baseKeymap)
    @loadKeymap(inputResetKeymap)
    @loadKeymap(basePlatformKeymap)

    # Load the template keymap (Gmail, Mail.app, etc.) the user has chosen
    templateConfigKey = 'core.keymapTemplate'
    templateKeymapPath = null
    reloadTemplateKeymap = =>
      @removeBindingsFromSource(templateKeymapPath) if templateKeymapPath
      templateFile = NylasEnv.config.get(templateConfigKey)
      if templateFile
        templateKeymapPath = fs.resolve(path.join(@resourcePath, 'keymaps', 'templates'), templateFile, ['cson', 'json'])
        if fs.existsSync(templateKeymapPath)
          @loadKeymap(templateKeymapPath)
          @emitter.emit('did-reload-keymap', {path: templateKeymapPath})
        else
          console.warn("Could not find #{templateKeymapPath}")

    NylasEnv.config.observe(templateConfigKey, reloadTemplateKeymap)
    reloadTemplateKeymap()

    @emitter.emit 'did-load-bundled-keymaps'

  getUserKeymapPath: ->
    if userKeymapPath = CSON.resolve(path.join(@configDirPath, 'keymap'))
      userKeymapPath
    else
      path.join(@configDirPath, 'keymap.cson')

  loadUserKeymap: ->
    userKeymapPath = @getUserKeymapPath()
    return unless fs.isFileSync(userKeymapPath)

    try
      @loadKeymap(userKeymapPath, watch: true, suppressErrors: true)
    catch error
      message = """
        Unable to watch path: `#{path.basename(userKeymapPath)}`. Make sure you
        have permission to read `#{userKeymapPath}`.
      """
      console.error(message, {dismissable: true})

  subscribeToFileReadFailure: ->
    @onDidFailToReadFile (error) =>
      userKeymapPath = @getUserKeymapPath()
      message = "Failed to load `#{userKeymapPath}`"

      detail = if error.location?
        error.stack
      else
        error.message

      console.error(message, {detail: detail, dismissable: true})

module.exports = KeymapManager

fs = require 'fs-plus'
path = require 'path'
CSON = require 'season'
AtomKeymap = require 'atom-keymap'

class KeymapManager extends AtomKeymap

  constructor: ->
    super
    @subscribeToFileReadFailure()

  onDidLoadBundledKeymaps: (callback) ->
    @emitter.on 'did-load-bundled-keymaps', callback

  # N1 adds the `cmdctrl` extension. This will use `cmd` or `ctrl` on a
  # mac, and `ctrl` only on windows and linux.
  readKeymap: (args...) ->
    re = /(cmdctrl|ctrlcmd)/i
    keymap = super(args...)
    for selector, keyBindings of keymap
      normalizedBindings = {}
      for keystrokes, command of keyBindings
        if re.test keystrokes
          if process.platform is "darwin"
            newKeystrokes1= keystrokes.replace(re, "ctrl")
            newKeystrokes2= keystrokes.replace(re, "cmd")
            normalizedBindings[newKeystrokes1] = command
            normalizedBindings[newKeystrokes2] = command
          else
            newKeystrokes = keystrokes.replace(re, "ctrl")
            normalizedBindings[newKeystrokes] = command
        else
          normalizedBindings[keystrokes] = command
      keymap[selector] = normalizedBindings

    return keymap

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
      templateFile = atom.config.get(templateConfigKey)
      if templateFile
        templateKeymapPath = fs.resolve(path.join(@resourcePath, 'keymaps', 'templates'), templateFile, ['cson', 'json'])
        if fs.existsSync(templateKeymapPath)
          @loadKeymap(templateKeymapPath)
          @emitter.emit('did-reload-keymap', {path: templateKeymapPath})
        else
          console.warn("Could not find #{templateKeymapPath}")

    atom.config.observe(templateConfigKey, reloadTemplateKeymap)
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

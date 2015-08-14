fs = require 'fs-plus'
path = require 'path'
KeymapManager = require 'atom-keymap'
CSON = require 'season'
{jQuery} = require 'space-pen'
Grim = require 'grim'

KeymapManager::onDidLoadBundledKeymaps = (callback) ->
  @emitter.on 'did-load-bundled-keymaps', callback

KeymapManager::loadBundledKeymaps = ->
  # Load the base keymap and the base.platform keymap
  baseKeymap = path.join(@resourcePath, 'keymaps', 'base.cson')
  basePlatformKeymap = path.join(@resourcePath, 'keymaps', "base.#{process.platform}.cson")
  @loadKeymap(baseKeymap)
  @loadKeymap(basePlatformKeymap)

  # Load the template keymap (Gmail, Mail.app, etc.) the user has chosen
  templateConfigKey = 'core.keymapTemplate'
  templateKeymapPath = null
  reloadTemplateKeymap = =>
    @removeBindingsFromSource(templateKeymapPath) if templateKeymapPath
    templateFile = atom.config.get(templateConfigKey)
    if templateFile
      templateKeymapPath = path.join(@resourcePath, 'keymaps', 'templates', templateFile)
      @loadKeymap(templateKeymapPath)
      @emitter.emit('did-reload-keymap', {path: templateKeymapPath})

  atom.config.observe(templateConfigKey, reloadTemplateKeymap)
  reloadTemplateKeymap()

  @emit 'bundled-keymaps-loaded' if Grim.includeDeprecatedAPIs
  @emitter.emit 'did-load-bundled-keymaps'

KeymapManager::getUserKeymapPath = ->
  if userKeymapPath = CSON.resolve(path.join(@configDirPath, 'keymap'))
    userKeymapPath
  else
    path.join(@configDirPath, 'keymap.cson')

KeymapManager::loadUserKeymap = ->
  userKeymapPath = @getUserKeymapPath()
  return unless fs.isFileSync(userKeymapPath)

  try
    @loadKeymap(userKeymapPath, watch: true, suppressErrors: true)
  catch error
    if error.message.indexOf('Unable to watch path') > -1
      message = """
        Unable to watch path: `#{path.basename(userKeymapPath)}`. Make sure you
        have permission to read `#{userKeymapPath}`.

        On linux there are currently problems with watch sizes. See
        [this document][watches] for more info.
        [watches]:https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path
      """
      console.error(message, {dismissable: true})
    else
      detail = error.path
      stack = error.stack
      atom.notifications.addFatalError(error.message, {detail, stack, dismissable: true})

KeymapManager::subscribeToFileReadFailure = ->
  @onDidFailToReadFile (error) =>
    userKeymapPath = @getUserKeymapPath()
    message = "Failed to load `#{userKeymapPath}`"

    detail = if error.location?
      error.stack
    else
      error.message

    console.error(message, {detail: detail, dismissable: true})

# This enables command handlers registered via jQuery to call
# `.abortKeyBinding()` on the `jQuery.Event` object passed to the handler.
jQuery.Event::abortKeyBinding = ->
  @originalEvent?.abortKeyBinding?()

module.exports = KeymapManager

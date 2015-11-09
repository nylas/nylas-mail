NylasStore = require 'nylas-store'
fs = require 'fs'
path = require 'path'
{Utils, MessageBodyProcessor} = require 'nylas-exports'
AutoloadImagesActions = require './autoload-images-actions'

# https://en.wikipedia.org/wiki/Comparison_of_web_browsers#Image_format_support
ImagesRegexp = /\/\/[^'"]*\.(jpg|jpeg|jpe|jif|jfif|jfi|png|xbm|bmp|dib|ico|pict|tiff|gif|pic|webp)+/gi

class AutoloadImagesStore extends NylasStore
  constructor: ->
    @_whitelistEmails = {}
    @_whitelistMessageIds = {}

    @_whitelistEmailsPath = path.join(atom.getConfigDirPath(), 'autoload-images-whitelist.txt')

    @_loadWhitelist()

    @listenTo AutoloadImagesActions.temporarilyEnableImages, @_onTemporarilyEnableImages
    @listenTo AutoloadImagesActions.permanentlyEnableImages, @_onPermanentlyEnableImages

    atom.config.observe 'core.reading.autoloadImages', =>
      MessageBodyProcessor.resetCache()

  shouldBlockImagesIn: (message) =>
    return false if atom.config.get('core.reading.autoloadImages') is true
    return false if @_whitelistEmails[Utils.toEquivalentEmailForm(message.fromContact().email)]
    return false if @_whitelistMessageIds[message.id]
    return false unless ImagesRegexp.test(message.body)
    true

  _loadWhitelist: =>
    fs.exists @_whitelistEmailsPath, (exists) =>
      return unless exists
      fs.readFile @_whitelistEmailsPath, (err, body) =>
        return console.log(err) if err or not body
        @_whitelistEmails = {}
        for email in body.toString().split(/[\n\r]+/)
          @_whitelistEmails[Utils.toEquivalentEmailForm(email)] = true

  _saveWhitelist: =>
    data = Object.keys(@_whitelistEmails).join('\n')
    fs.writeFile @_whitelistEmailsPath, data, (err) =>
      console.error("AutoloadImagesStore could not save whitelist: #{err.toString()}") if err

  _onTemporarilyEnableImages: (message) ->
    @_whitelistMessageIds[message.id] = true
    MessageBodyProcessor.resetCache()

  _onPermanentlyEnableImages: (message) ->
    @_whitelistEmails[Utils.toEquivalentEmailForm(message.fromContact().email)] = true
    MessageBodyProcessor.resetCache()
    setTimeout(@_saveWhitelist, 1)

module.exports = new AutoloadImagesStore
module.exports.ImagesRegexp = ImagesRegexp

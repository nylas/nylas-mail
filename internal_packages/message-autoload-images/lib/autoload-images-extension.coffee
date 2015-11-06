AutoloadImagesStore = require './autoload-images-store'
{MessageStoreExtension} = require 'nylas-exports'

class AutoloadImagesExtension extends MessageStoreExtension

  @formatMessageBody: (message) ->
    if AutoloadImagesStore.shouldBlockImagesIn(message)
      message.body = message.body.replace AutoloadImagesStore.ImagesRegexp, (match, text) ->
        "//#"

module.exports = AutoloadImagesExtension

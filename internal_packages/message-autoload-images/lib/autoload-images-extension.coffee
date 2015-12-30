AutoloadImagesStore = require './autoload-images-store'
{MessageViewExtension} = require 'nylas-exports'

class AutoloadImagesExtension extends MessageViewExtension

  @formatMessageBody: ({message}) ->
    if AutoloadImagesStore.shouldBlockImagesIn(message)
      message.body = message.body.replace AutoloadImagesStore.ImagesRegexp, (match, prefix, imageUrl) ->
        "#{prefix}#"

module.exports = AutoloadImagesExtension

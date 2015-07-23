Autolinker = require 'autolinker'
{MessageStoreExtension} = require 'nylas-exports'

class AutolinkerExtension extends MessageStoreExtension

  @formatMessageBody: (message) ->
    # Apply the autolinker pass to make emails and links clickable
    message.body = Autolinker.link(message.body, {twitter: false})

module.exports = AutolinkerExtension

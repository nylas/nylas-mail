Autolinker = require 'autolinker'
{MessageViewExtension} = require 'nylas-exports'

class AutolinkerExtension extends MessageViewExtension

  @formatMessageBody: ({message}) ->
    # Apply the autolinker pass to make emails and links clickable
    message.body = Autolinker.link(message.body, {twitter: false})

    # Ensure that the hrefs in the email always have alt text so you can't hide
    # the target of links
    # https://regex101.com/r/cH0qM7/1
    message.body = message.body.replace /href[ ]*=[ ]*?['"]([^'"]*)(['"]+)/gi, (match, url, quoteCharacter) =>
      return "#{match} title=#{quoteCharacter}#{url}#{quoteCharacter} "

module.exports = AutolinkerExtension

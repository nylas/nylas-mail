Autolinker = require 'autolinker'
{RegExpUtils, MessageViewExtension} = require 'nylas-exports'

class AutolinkerExtension extends MessageViewExtension

  @formatMessageBody: ({message}) ->
    # Apply the autolinker pass to make emails and links clickable
    message.body = Autolinker.link(message.body, {twitter: false})

    # Ensure that the hrefs in the email always have alt text so you can't hide
    # the target of links
    # https://regex101.com/r/cH0qM7/1
    titleRe = -> /title\s.*?=\s.*?['"](.*)['"]/gi
    message.body = message.body.replace RegExpUtils.linkTagRegex(), (match, openTagPrefix, aTagHref, openTagSuffix, content, closingTag) =>
      if not content or not closingTag
        return match

      openTag = openTagPrefix + aTagHref + openTagSuffix

      if titleRe().test(openTag)
        oldTitle = titleRe().exec(openTag)[1]
        title = """ title="#{oldTitle} | #{aTagHref}" """
        openTag = openTag.replace(titleRe(), title)
      else
        title = """ title="#{aTagHref}" """
        tagLen = openTag.length
        openTag = openTag.slice(0, tagLen - 1) + title + openTag.slice(tagLen - 1, tagLen)

      return openTag + content + closingTag

module.exports = AutolinkerExtension

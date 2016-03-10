_ = require('underscore')
RegExpUtils =

  # It's important that the regex be wrapped in parens, otherwise
  # javascript's RegExp::exec method won't find anything even when the
  # regex matches!
  #
  # It's also imporant we return a fresh copy of the RegExp every time. A
  # javascript regex is stateful and multiple functions using this method
  # will cause unexpected behavior!
  #
  # See http://tools.ietf.org/html/rfc5322#section-3.4 and
  # https://tools.ietf.org/html/rfc6531 and
  # https://en.wikipedia.org/wiki/Email_address#Local_part
  emailRegex: -> new RegExp(/([a-z.A-Z0-9!#$%&'*+\-/=?^_`{|}~;:]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63})/g)

  # http://stackoverflow.com/a/16463966
  # http://www.regexpal.com/?fam=93928
  # NOTE: This does not match full urls with `http` protocol components.
  domainRegex: -> new RegExp(/^(?!:\/\/)([a-zA-Z0-9-_]+\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\.[a-zA-Z]{2,11}?/i)

  # Test cases: https://regex101.com/r/pD7iS5/2
  # http://daringfireball.net/2010/07/improved_regex_for_matching_urls
  # https://mathiasbynens.be/demo/url-regex
  # This is the Gruber Regex.
  urlRegex: ({matchEntireString} = {}) ->
    if matchEntireString
      new RegExp(/^\b((?:https?:\/\/|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))$/)
    else
      new RegExp(/\b((?:https?:\/\/|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))$/)

  # Test cases: https://regex101.com/r/jD5zC7/2
  # Returns the following capturing groups:
  # 1. start of the opening a tag to href="
  # 2. The contents of the href without quotes
  # 3. the rest of the opening a tag
  # 4. the contents of the a tag
  # 5. the closing tag
  linkTagRegex: -> new RegExp(/(<a.*?href\s*?=\s*?['"])(.*?)(['"].*?>)([\s\S]*?)(<\/a>)/gim)

  # Test cases: https://regex101.com/r/cK0zD8/3
  # Catches link tags containing which are:
  # - Non empty
  # - Not a mailto: link
  # Returns the following capturing groups:
  # 1. start of the opening a tag to href="
  # 2. The contents of the href without quotes
  # 3. the rest of the opening a tag
  # 4. the contents of the a tag
  # 5. the closing tag
  urlLinkTagRegex: -> new RegExp(/(<a.*?href\s*?=\s*?['"])((?!mailto).+)(['"].*?>)([\s\S]*?)(<\/a>)/gim)

  # https://regex101.com/r/zG7aW4/3
  imageTagRegex: -> /<img\s+[^>]*src="([^"]*)"[^>]*>/g

  punctuation: ({exclude}={}) ->
    exclude ?= []
    punctuation = [ '.', ',', '\\/', '#', '!', '$', '%', '^', '&', '*',
      ';', ':', '{', '}', '=', '\\-', '_', '`', '~', '(', ')', '@', '+',
      '?', '>', '<', '\\[', '\\]', '+' ]
    punctuation = _.difference(punctuation, exclude).join('')
    return new RegExp("[#{punctuation}]", 'g')

  # This tests for valid schemes as per RFC 3986
  # We need both http: https: and mailto: and a variety of other schemes.
  # This does not check for invalid usage of the http: scheme. For
  # example, http:bad.com would pass. We do not check for
  # protocol-relative uri's.
  #
  # Regex explanation here: https://regex101.com/r/nR2yL6/2
  # See RFC here: https://tools.ietf.org/html/rfc3986#section-3.1
  # SO discussion: http://stackoverflow.com/questions/10687099/how-to-test-if-a-url-string-is-absolute-or-relative/31991870#31991870
  hasValidSchemeRegex: -> new RegExp('^[a-z][a-z0-9+.-]*:', 'i')

  looseStyleTag: -> /<style/gim

  # Regular expression matching javasript function arguments:
  # https://regex101.com/r/pZ6zF0/1
  functionArgs: -> /\(\s*([^)]+?)\s*\)/

  illegalPathCharactersRegexp: ->
    #https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx
    /[\\\/:|?*><"]/g

module.exports = RegExpUtils

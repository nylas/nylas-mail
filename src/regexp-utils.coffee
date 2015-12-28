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

  # https://regex101.com/r/zG7aW4/3
  imageTagRegex: -> /<img\s+[^>]*src="([^"]*)"[^>]*>/g

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

module.exports = RegExpUtils

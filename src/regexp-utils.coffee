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

  # http://stackoverflow.com/questions/16631571/javascript-regular-expression-detect-all-the-phone-number-from-the-page-source
  # http://www.regexpal.com/?fam=94521
  # NOTE: This is not exhaustive, and balances what is technically a phone number
  # with what would be annoying to linkify. eg: 12223334444 does not match.
  phoneRegex: -> new RegExp(/([\+\(]+|\b)(?:(\d{1,3}[- ()]*)?)(\d{3})[- )]+(\d{3})[- ]+(\d{4})(?: *x(\d+))?\b/g)

  # http://stackoverflow.com/a/16463966
  # http://www.regexpal.com/?fam=93928
  # NOTE: This does not match full urls with `http` protocol components.
  domainRegex: -> new RegExp(/^(?!:\/\/)([a-zA-Z0-9-_]+\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\.[a-zA-Z]{2,11}?/i)

  # https://www.safaribooksonline.com/library/view/regular-expressions-cookbook/9780596802837/ch07s16.html
  ipAddressRegex: -> new RegExp(/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/i)

  # Test cases: https://regex101.com/r/pD7iS5/3
  urlRegex: ({matchEntireString} = {}) ->
    commonTlds = ['com', 'org', 'edu', 'gov', 'uk', 'net', 'ca', 'de', 'jp', 'fr', 'au', 'us', 'ru', 'ch', 'it', 'nl', 'se', 'no', 'es', 'mil']

    parts = [
      '('
        # one of:
        '('
          # This OR block matches any TLD if the URL includes a scheme, and only
          # the top ten TLDs if the scheme is omitted.
          # YES - https://nylas.ai
          # YES - https://10.2.3.1
          # YES - nylas.com
          # NO  - nylas.ai
          '('
            # scheme, ala https:// (mandatory)
            '([A-Za-z]{3,9}:(?:\\/\\/))'

            # username:password (optional)
            '(?:[\\-;:&=\\+\\$,\\w]+@)?'

            # one of:
            '('
              # domain with any tld
              '([a-zA-Z0-9-_]+\\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\\.[a-zA-Z]{2,11}'

              '|'

              # ip address
              '(?:[0-9]{1,3}\\.){3}[0-9]{1,3}'
            ')'

            '|'

            # scheme, ala https:// (optional)
            '([A-Za-z]{3,9}:(?:\\/\\/))?'

            # username:password (optional)
            '(?:[\\-;:&=\\+\\$,\\w]+@)?'

            # one of:
            '('
              # domain with common tld
              '([a-zA-Z0-9-_]+\\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\\.(?:' + commonTlds.join('|') + ')'

              '|'

              # ip address
              '(?:[0-9]{1,3}\\.){3}[0-9]{1,3}'
            ')'
          ')'

          # :port (optional)
          '(?::\d*)?'

          '|'

          # mailto:username@password.com
          'mailto:\\/*(?:\\w+\\.|[\\-;:&=\\+\\$.,\\w]+@)[A-Za-z0-9\\.\\-]+'
        ')'

        # optionally followed by:
        '('
          # URL components
          # (last character must not be puncation, hence two groups)
          '(?:[\\+~%\\/\\.\\w\\-_@]*[\\+~%\\/\\w\\-_]+)?'

          # optionally followed by: a query string and/or a #location
          # (last character must not be puncation, hence two groups)
          '(?:(\\?[\\-\\+=&;%@\\.\\w_]*[\\-\\+=&;%@\\w_\\/]+)?#?(?:[\\.\\!\\/\\\\\\w]*[\\/\\\\\\w]+)?)?'
        ')?'
      ')'
    ]
    if matchEntireString
      parts.unshift('^')

    return new RegExp(parts.join(''), 'gi')

  # Test cases: https://regex101.com/r/jD5zC7/2
  # Returns the following capturing groups:
  # 1. start of the opening a tag to href="
  # 2. The contents of the href without quotes
  # 3. the rest of the opening a tag
  # 4. the contents of the a tag
  # 5. the closing tag
  linkTagRegex: -> new RegExp(/(<a.*?href\s*?=\s*?['"])(.*?)(['"].*?>)([\s\S]*?)(<\/a>)/gim)

  # Test cases: https://regex101.com/r/cK0zD8/4
  # Catches link tags containing which are:
  # - Non empty
  # - Not a mailto: link
  # Returns the following capturing groups:
  # 1. start of the opening a tag to href="
  # 2. The contents of the href without quotes
  # 3. the rest of the opening a tag
  # 4. the contents of the a tag
  # 5. the closing tag
  urlLinkTagRegex: -> new RegExp(/(<a.*?href\s*?=\s*?['"])((?!mailto).+?)(['"].*?>)([\s\S]*?)(<\/a>)/gim)

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

  # https://regex101.com/r/nC0qL2/2
  signatureRegex: ->
    new RegExp(/(<br\/>){0,2}<signature>[^]*<\/signature>/)

  # Finds the start of a quoted text region as inserted by N1. This is not
  # a general-purpose quote detection scheme and only works for
  # N1-composed emails.
  n1QuoteStartRegex: ->
    new RegExp(/<\w+[^>]*gmail_quote/i)

module.exports = RegExpUtils

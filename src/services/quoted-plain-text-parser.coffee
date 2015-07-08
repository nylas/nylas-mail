_ = require 'underscore'
_str = require 'underscore.string'

# Parses plain text emails to find quoted text and signatures.
#
# For plain text emails we look for lines that look like they're quoted
# text based on common conventions:
#
# For HTML emails use QuotedHTMLParser
#
# This is modied from https://github.com/mko/emailreplyparser, which is a
# JS port of GitHub's Ruby https://github.com/github/email_reply_parser
QuotedPlainTextParser =
  parse: (text) ->
    parsedEmail = new ParsedEmail
    parsedEmail.parse text

  visibleText: (text, {showQuoted, showSignature}={}) ->
    showQuoted ?= false
    showSignature ?= false
    @parse(text).visibleText({showQuoted, showSignature})

  hiddenText: (text, {showQuoted, showSignature}={}) ->
    showQuoted ?= false
    showSignature ?= false
    @parse(text).hiddenText({showQuoted, showSignature})

  hasQuotedHTML: (text) ->
    return @parse(text).hasQuotedHTML()

chomp = ->
  @replace /(\n|\r)+$/, ''

# An ParsedEmail instance contains various `Fragment`s that indicate if we
# think a section of text is quoted or is a signature
class ParsedEmail
  constructor: ->
    @fragments = []
    @currentFragment = null
    return

  fragments: []

  hasQuotedHTML: ->
    for fragment in @fragments
      return true if fragment.quoted
    return false

  visibleText: ({showSignature, showQuoted}={}) ->
    @_setHiddenState({showSignature, showQuoted})
    return _.reject(@fragments, (f) -> f.hidden).map((f) -> f.to_s()).join('\n')

  hiddenText: ({showSignature, showQuoted}={}) ->
    @_setHiddenState({showSignature, showQuoted})
    return _.filter(@fragments, (f) -> f.hidden).map((f) -> f.to_s()).join('\n')

  # We set a hidden state just so we can test the expected output in our
  # specs. The hidden state is determined by the requested view parameters
  # and the `quoted` flag on each `fragment`
  _setHiddenState: ({showSignature, showQuoted}={}) ->
    fragments = _.reject @fragments, (f) ->
      if f.to_s().trim() is ""
        f.hidden = true
        return true
      else return false

    for fragment, i in fragments
      fragment.hidden = true
      if fragment.quoted
        if showQuoted or (fragments[i+1]? and not (fragments[i+1].quoted or fragments[i+1].signature))
          fragment.hidden = false
          continue
        else continue

      if fragment.signature
        if showSignature
          fragment.hidden = false
          continue
        else continue

      fragment.hidden = false

  parse: (text) ->

    # This instance variable points to the current Fragment.  If the matched
    # line fits, it should be added to this Fragment.  Otherwise, finish it
    # and start a new Fragment.
    @currentFragment = null
    @_parsePlain(text)

  _parsePlain: (text) ->
    # Check for multi-line reply headers. Some clients break up
    # the "On DATE, NAME <EMAIL> wrote:" line into multiple lines.
    patt = /^(On\s(\n|.)*wrote:)$/m
    doubleOnPatt = /^(On\s(\n|.)*(^(> )?On\s)((\n|.)*)wrote:)$/m
    if patt.test(text) and !doubleOnPatt.test(text)
      replyHeader = patt.exec(text)[0]
      # Remove all new lines from the reply header.
      text = text.replace(replyHeader, replyHeader.replace(/\n/g, ' '))

    # The text is reversed initially due to the way we check for hidden
    # fragments.
    text = _str.reverse(text)

    # Use the StringScanner to pull out each line of the email content.
    lines = text.split('\n')

    for i of lines
      @_scanPlainLine lines[i]

    # Finish up the final fragment.  Finishing a fragment will detect any
    # attributes (hidden, signature, reply), and join each line into a
    # string.
    @_finishFragment()

    # Now that parsing is done, reverse the order.
    @fragments.reverse()

    return @

  _signatureRE:
    /(--|__|^-\w)|(^sent from my (\s*\w+){1,3}$)/i

  # NOTE: Plain lines are scanned bottom to top. We reverse the text in
  # `_parsePlain`
  _scanPlainLine: (line) ->
    line = chomp.apply(line)

    if !new RegExp(@_signatureRE).test(_str.reverse(line))
      line = _str.ltrim(line)

    # Mark the current Fragment as a signature if the current line is ''
    # and the Fragment starts with a common signature indicator.
    if @currentFragment != null and line == ''
      if new RegExp(@_signatureRE).test(_str.reverse(@currentFragment.lines[@currentFragment.lines.length - 1]))
        @currentFragment.signature = true
        @_finishFragment()

    # We're looking for leading `>`'s to see if this line is part of a
    # quoted Fragment.
    isQuoted = new RegExp('(>+)$').test(line)

    # If the line matches the current fragment, add it.  Note that a common
    # reply header also counts as part of the quoted Fragment, even though
    # it doesn't start with `>`.
    if @currentFragment != null and (@currentFragment.quoted == isQuoted or @currentFragment.quoted and (@_quoteHeader(line) or line == ''))
      @currentFragment.lines.push line
    else
      @_finishFragment()
      @currentFragment = new Fragment(isQuoted, line, "plain")
    return

  _quoteHeader: (line) ->
    new RegExp('^:etorw.*nO$').test line

  _finishFragment: ->
    if @currentFragment != null
      @currentFragment.finish()
      @fragments.push @currentFragment
      @currentFragment = null
    return

# Represents a group of paragraphs in the email sharing common attributes.
# Paragraphs should get their own fragment if they are a quoted area or a
# signature.
class Fragment
  constructor: (@quoted, firstLine) ->
    @signature = false
    @hidden = false
    @lines = [ firstLine ]
    @content = null
    @lines = @lines.filter(->
      true
    )
    return

  content: null

  finish: ->
    @content = @lines.join("\n")
    @lines = []

    @content = _str.reverse(@content)

    return

  to_s: ->
    @content.toString().trim()

module.exports = QuotedPlainTextParser

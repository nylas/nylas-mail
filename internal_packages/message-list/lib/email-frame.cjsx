React = require 'react'
_ = require "underscore-plus"

EmailFixingStyles = """
  <style>
  /* Styles for an email iframe */
  @font-face {
    font-family: 'FaktPro';
    font-style: normal;
    font-weight: 300;
    src: local('FaktPro-Blond'), url('fonts/Fakt/FaktPro-Blond.ttf'), local('Comic Sans MS');
  }

  @font-face {
    font-family: 'FaktPro';
    font-style: normal;
    font-weight: 400;
    src: local('FaktPro-Normal'), url('fonts/Fakt/FaktPro-Normal.ttf'), local('Comic Sans MS');
  }

  @font-face {
    font-family: 'FaktPro';
    font-style: normal;
    font-weight: 500;
    src: local('FaktPro-Medium'), url('fonts/Fakt/FaktPro-Medium.ttf'), local('Comic Sans MS');
  }

  @font-face {
    font-family: 'FaktPro';
    font-style: normal;
    font-weight: 600;
    src: local('FaktPro-SemiBold'), url('fonts/Fakt/FaktPro-SemiBold.ttf'), local('Comic Sans MS');
  }

  /* Clean Message Display */
  html, body {
    font-family: "FaktPro", "Helvetica", "Lucidia Grande", sans-serif;
    font-size: 16px;
    line-height: 1.5;

    color: #313435;

    border: 0;
    margin: 0;
    padding: 0;

    -webkit-text-size-adjust: auto;
    word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;
  }

  strong, b, .bold {
    font-weight: 600;
  }

  body {
    padding: 0;
    margin: auto;
    max-width: 840px;
    overflow: hidden;
    -webkit-font-smoothing: antialiased;
  }

  a {
    color: #2794c3;
  }

  a:hover {
    color: #1f7498;
  }

  a:visited {
    color: #1f7498;
  }
  a img {
    border-bottom: 0;
  }

  body.heightDetermined {
    overflow-y: hidden;
  }

  div,pre {
    max-width: 100%;
  }

  img {
    max-width: 100%;
    height: auto;
    border: 0;
  }

  .gmail_extra,
  .gmail_quote,
  blockquote {
    display:none;
  }

  .show-quoted-text .gmail_extra,
  .show-quoted-text .gmail_quote,
  .show-quoted-text blockquote {
    display:inherit;
  }
  </style>
"""

module.exports =
EmailFrame = React.createClass
  displayName: 'EmailFrame'

  render: ->
    <iframe seamless="seamless" />

  componentDidMount: ->
    @_writeContent()
    @_setFrameHeight()

  componentDidUpdate: ->
    @_writeContent()
    @_setFrameHeight()

  componentWillUnmount: ->
    doc = @getDOMNode().contentDocument
    doc?.removeEventListener?("click")
    doc?.removeEventListener?("keydown")
    @_delegateMouseEvents(doc, "removeEventListener")

  shouldComponentUpdate: (newProps, newState) ->
    # Turns out, React is not able to tell if props.children has changed,
    # so whenever the message list updates each email-frame is repopulated,
    # often with the exact same content. To avoid unnecessary calls to
    # _writeContent, we do a quick check for deep equality.
    !_.isEqual(newProps, @props)

  _writeContent: ->
    wrapperClass = if @props.showQuotedText then "show-quoted-text" else ""
    doc = @getDOMNode().contentDocument
    doc.open()
    doc.write(EmailFixingStyles)
    doc.write("<div id='inbox-html-wrapper' class='#{wrapperClass}'>#{@_emailContent()}</div>")
    doc.close()
    doc.addEventListener "click", @_onClick
    doc.addEventListener "keydown", @_onKeydown
    @_delegateMouseEvents(doc, "addEventListener")

  _setFrameHeight: ->
    _.defer =>
      return unless @isMounted()
      # Sometimes the _defer will fire after React has tried to clean up
      # the DOM, at which point @getDOMNode will fail.
      #
      # If this happens, try to call this again to catch React next time.
      try
        domNode = @getDOMNode()
      catch
        return

      doc = domNode.contentDocument
      height = doc.getElementById("inbox-html-wrapper").scrollHeight
      if domNode.height != "#{height}px"
        domNode.height = "#{height}px"

      unless domNode?.contentDocument?.readyState is 'complete'
        @_setFrameHeight()

  _emailContent: ->
    email = @props.children

    # When showing quoted text, always return the pure content
    return email if @props.showQuotedText

    # Split the email into lines and remove lines that begin with > or &gt;
    lines = email.split(/(\n|<br[^>]*>)/)

    # Remove lines that are newlines - we'll add them back in when we join.
    # We had to break them out because we want to preserve <br> elements.
    lines = _.reject lines, (line) -> line == '\n'

    regexs = [
      /\n[ ]*(>|&gt;)/, # Plaintext lines beginning with >
      /<[br|p][ ]*>[\n]?[ ]*[>|&gt;]/i, # HTML lines beginning with >
      /[\n|>]On .* wrote:[\n|<]/, #On ... wrote: on it's own line
    ]
    for ii in [lines.length-1..0] by -1
      for regex in regexs
        # Never remove a line with a blockquote start tag, because it
        # quotes multiple lines, not just the current line!
        if lines[ii].match("<blockquote")
          break
        if lines[ii].match(regex)
          lines.splice(ii,1)
          # Remove following line if its just a spacer-style element
          lines.splice(ii,1) if lines[ii].match('<br[^>]*>')?[0] is lines[ii]
          break

    # Return remaining compacted email body
    lines.join('\n')

  _onClick: (e) ->
    e.preventDefault()
    e.stopPropagation()
    target = e.target

    # This lets us detect when we click an element inside of an <a> tag
    while target? and (target isnt document) and (target isnt window)
      if target.getAttribute('href')?
        atom.windowEventHandler.openLink target: target
        target = null
      else
        target = target.parentElement

  _onKeydown: (event) ->
    @getDOMNode().dispatchEvent(new KeyboardEvent(event.type, event))

  _delegateMouseEvents: (doc, method="addEventListener") ->
    for type in ["mousemove", "mouseup", "mousedown", "mouseover", "mouseout"]
      doc?[method]?(type, @_onMouseEvent)

  _onMouseEvent: (event) ->
    {top, left} = @getDOMNode().getBoundingClientRect()
    new_coords = {clientX: event.clientX + left, clientY: event.clientY + top}
    new_event = _.extend {}, event, new_coords
    @getDOMNode().dispatchEvent(new MouseEvent(event.type, new_event))

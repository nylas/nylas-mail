React = require 'react'
_ = require "underscore-plus"

EmailFixingStyles = """
  <style>
  /* Styles for an email iframe */
  @font-face {
    font-family: 'Proxima Nova Regular';
    src: url('fonts/Proxima-Nova/regular.woff') format('woff');
    font-weight: normal;
    font-style: normal;
  }
  @font-face {
    font-family: 'Proxima Nova Bold';
    src: url('fonts/Proxima-Nova/bold.woff') format('woff');
    font-weight: normal;
    font-style: normal;
  }

  /* Clean Message Display */
  html, body {
    font-family: "Proxima Nova Regular", sans-serif;
    font-size: 16px;
    line-height: 1.35;

    color: #333;

    border: 0;
    margin: 0;
    padding: 0;

    -webkit-text-size-adjust: auto;
    word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;
  }

  ::selection {
    color: #f1f1f1;
    background: #009ec4;
  }

  strong, b, .bold {
    font-family: "Proxima Nova Bold", sans-serif;
    font-weight: normal;
    font-style: normal;
    letter-spacing: 0.3px;
  }

  body {
    padding: 0;
    margin: auto;
    max-width: 840px;
    overflow: hidden;
  }

  a {
    color: #1486D4;
  }

  a:hover {
    color: #1069a5;
  }

  a:visited {
    color: #1069a5;
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
    lines = email.split(/(\n|<br>)/)

    # Remove lines that are newlines - we'll add them back in when we join.
    # We had to break them out because we want to preserve <br> elements.
    lines = _.reject lines, (line) -> line == '\n'

    for ii in [lines.length-1..0] by -1
      if (lines[ii].substr(0, 1) == '>' ||
          lines[ii].substr(0, 4) == '\&gt;' ||
          lines[ii].substr(0, 10) == '<p>\&gt; On')
        lines.splice(ii+1,1) if lines[ii+1] == '<br>' # Remove following newline if it's a <br>
        lines.splice(ii,1)

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

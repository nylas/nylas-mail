React = require 'react'
_ = require "underscore"
{EventedIFrame} = require 'nylas-component-kit'
{Utils} = require 'nylas-exports'

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

  pre {
    white-space: normal;
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
  #divRplyFwdMsg,
  blockquote {
    display:none;
  }

  .show-quoted-text .gmail_extra,
  .show-quoted-text .gmail_quote,
  .show-quoted-text #divRplyFwdMsg,
  .show-quoted-text blockquote {
    display:inherit;
  }
  </style>
"""

class EmailFrame extends React.Component
  @displayName = 'EmailFrame'

  render: =>
    <EventedIFrame ref="iframe" seamless="seamless" />

  componentDidMount: =>
    @_mounted = true
    @_writeContent()
    @_setFrameHeight()

  componentWillUnmount: =>
    @_mounted = false

  componentDidUpdate: =>
    @_writeContent()
    @_setFrameHeight()

  shouldComponentUpdate: (newProps, newState) =>
    # Turns out, React is not able to tell if props.children has changed,
    # so whenever the message list updates each email-frame is repopulated,
    # often with the exact same content. To avoid unnecessary calls to
    # _writeContent, we do a quick check for deep equality.
    !_.isEqual(newProps, @props)

  _writeContent: =>
    wrapperClass = if @props.showQuotedText then "show-quoted-text" else ""
    doc = React.findDOMNode(@).contentDocument
    doc.open()
    doc.write(EmailFixingStyles)
    doc.write("<div id='inbox-html-wrapper' class='#{wrapperClass}'>#{@_emailContent()}</div>")
    doc.close()

    # Notify the EventedIFrame that we've replaced it's document (with `open`)
    # so it can attach event listeners again.
    @refs.iframe.documentWasReplaced()

  _setFrameHeight: =>
    _.defer =>
      return unless @_mounted
      domNode = React.findDOMNode(@)
      doc = domNode.contentDocument
      height = doc.getElementById("inbox-html-wrapper").scrollHeight
      if domNode.height != "#{height}px"
        domNode.height = "#{height}px"

      unless domNode?.contentDocument?.readyState is 'complete'
        @_setFrameHeight()

  _emailContent: =>
    email = @props.children

    # When showing quoted text, always return the pure content
    if @props.showQuotedText
      email
    else
      Utils.stripQuotedText(email)


module.exports = EmailFrame

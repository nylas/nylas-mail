React = require 'react'
_ = require "underscore"
{EventedIFrame} = require 'nylas-component-kit'
{QuotedHTMLParser} = require 'nylas-exports'

class EmailFrame extends React.Component
  @displayName = 'EmailFrame'

  @propTypes:
    content: React.PropTypes.string.isRequired

  constructor: (@props) ->
    @_lastComputedHeight = 0

  render: =>
    <EventedIFrame ref="iframe" seamless="seamless" onResize={@_setFrameHeight}/>

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

    # NOTE: The iframe must have a modern DOCTYPE. The lack of this line
    # will cause some bizzare non-standards compliant rendering with the
    # message bodies. This is particularly felt with <table> elements use
    # the `border-collapse: collapse` css property while setting a
    # `padding`.
    doc.write("<!DOCTYPE html>")

    EmailFixingStyles = document.querySelector('[source-path*="email-frame.less"]')?.innerText
    EmailFixingStyles = EmailFixingStyles.replace(/.ignore-in-parent-frame/g, '')
    if (EmailFixingStyles)
      doc.write("<style>#{EmailFixingStyles}</style>")
    doc.write("<div id='inbox-html-wrapper' class='#{wrapperClass}'>#{@_emailContent()}</div>")
    doc.close()

    # Notify the EventedIFrame that we've replaced it's document (with `open`)
    # so it can attach event listeners again.
    @refs.iframe.documentWasReplaced()

  _setFrameHeight: =>
    return unless @_mounted

    domNode = React.findDOMNode(@)
    wrapper = domNode.contentDocument.getElementById("inbox-html-wrapper")
    height = wrapper.scrollHeight

    # Why 5px? Some emails have elements with a height of 100%, and then put
    # tracking pixels beneath that. In these scenarios, the scrollHeight of the
    # message is always <100% + 1px>, which leads us to resize them constantly.
    # This is a hack, but I'm not sure of a better solution.
    if Math.abs(height - @_lastComputedHeight) > 5
      domNode.height = "#{height}px"
      @_lastComputedHeight = height

    unless domNode?.contentDocument?.readyState is 'complete'
      _.defer => @_setFrameHeight()

  _emailContent: =>
    # When showing quoted text, always return the pure content
    if @props.showQuotedText
      @props.content
    else
      QuotedHTMLParser.hideQuotedHTML(@props.content)


module.exports = EmailFrame

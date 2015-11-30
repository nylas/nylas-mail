React = require 'react'
_ = require "underscore"
{EventedIFrame} = require 'nylas-component-kit'
{QuotedHTMLParser} = require 'nylas-exports'

EmailFrameStylesStore = require './email-frame-styles-store'

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
    @_unlisten = EmailFrameStylesStore.listen(@_writeContent)

  componentWillUnmount: =>
    @_mounted = false
    @_unlisten?()

  componentDidUpdate: =>
    @_writeContent()

  shouldComponentUpdate: (newProps, newState) =>
    # Turns out, React is not able to tell if props.children has changed,
    # so whenever the message list updates each email-frame is repopulated,
    # often with the exact same content. To avoid unnecessary calls to
    # _writeContent, we do a quick check for deep equality.
    !_.isEqual(newProps, @props)

  _writeContent: =>
    doc = React.findDOMNode(@).contentDocument
    return unless doc

    doc.open()

    # NOTE: The iframe must have a modern DOCTYPE. The lack of this line
    # will cause some bizzare non-standards compliant rendering with the
    # message bodies. This is particularly felt with <table> elements use
    # the `border-collapse: collapse` css property while setting a
    # `padding`.
    doc.write("<!DOCTYPE html>")
    styles = EmailFrameStylesStore.styles()
    if (styles)
      doc.write("<style>#{styles}</style>")
    doc.write("<div id='inbox-html-wrapper'>#{@_emailContent()}</div>")
    doc.close()

    # Notify the EventedIFrame that we've replaced it's document (with `open`)
    # so it can attach event listeners again.
    @refs.iframe.documentWasReplaced()
    @_setFrameHeight()

  _setFrameHeight: =>
    return unless @_mounted

    domNode = React.findDOMNode(@)
    wrapper = domNode.contentDocument.getElementsByTagName('html')[0]
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
      QuotedHTMLParser.removeQuotedHTML(@props.content, keepIfWholeBodyIsQuote: true)


module.exports = EmailFrame

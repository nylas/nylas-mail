React = require 'react'
_ = require "underscore"
{EventedIFrame} = require 'nylas-component-kit'
{Utils, QuotedHTMLTransformer} = require 'nylas-exports'

EmailFrameStylesStore = require './email-frame-styles-store'

class EmailFrame extends React.Component
  @displayName = 'EmailFrame'

  @propTypes:
    content: React.PropTypes.string.isRequired

  render: =>
    <EventedIFrame ref="iframe" seamless="seamless" searchable={true}
      onResize={@_setFrameHeight}/>

  componentDidMount: =>
    @_mounted = true
    @_writeContent()
    @_unlisten = EmailFrameStylesStore.listen(@_writeContent)

  componentWillUnmount: =>
    @_mounted = false
    @_unlisten?()

  componentDidUpdate: =>
    @_writeContent()

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  _writeContent: =>
    @_lastComputedHeight = 0
    domNode = React.findDOMNode(@)
    doc = domNode.contentDocument
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
    domNode.height = '0px'
    @_setFrameHeight()

  _getFrameHeight: (doc) ->
    return 0 unless doc
    return doc.body?.scrollHeight ? doc.documentElement?.scrollHeight ? 0

  _setFrameHeight: =>
    return unless @_mounted

    domNode = React.findDOMNode(@)
    height = @_getFrameHeight(domNode.contentDocument)

    # Why 5px? Some emails have elements with a height of 100%, and then put
    # tracking pixels beneath that. In these scenarios, the scrollHeight of the
    # message is always <100% + 1px>, which leads us to resize them constantly.
    # This is a hack, but I'm not sure of a better solution.
    if Math.abs(height - @_lastComputedHeight) > 5
      domNode.height = "#{height}px"
      @_lastComputedHeight = height

    unless domNode.contentDocument?.readyState is 'complete'
      _.defer => @_setFrameHeight()

  _emailContent: =>
    # When showing quoted text, always return the pure content
    if @props.showQuotedText
      @props.content
    else
      QuotedHTMLTransformer.removeQuotedHTML(@props.content, keepIfWholeBodyIsQuote: true)


module.exports = EmailFrame

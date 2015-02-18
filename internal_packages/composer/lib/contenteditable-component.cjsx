_ = require 'underscore-plus'
React = require 'react'
sanitizeHtml = require 'sanitize-html'
{Utils} = require 'inbox-exports'

module.exports =
ContenteditableComponent = React.createClass

  getInitialState: ->
    editQuotedText: false

  getEditableNode: ->
    @refs.contenteditable.getDOMNode()

  render: ->
    quotedTextClass = React.addons.classSet
      "quoted-text-toggle": true
      'hidden': @_htmlQuotedTextStart() is -1
      'state-on': @state.editQuotedText

    <div className="contenteditable-container">
      <div id="contenteditable"
           ref="contenteditable"
           className="scribe native-key-bindings"
           contentEditable
           onInput={@_onChange}
           onPaste={@_onPaste}
           tabIndex={@props.tabIndex}
           onBlur={@_onChange}
           dangerouslySetInnerHTML={{__html: @_htmlForDisplay()}}></div>
      <a className={quotedTextClass} onClick={@_onToggleQuotedText}></a>
    </div>

  shouldComponentUpdate: (nextProps, nextState) ->
    return true if nextState.editQuotedText is not @state.editQuotedText

    html = @getEditableNode().innerHTML
    return (nextProps.html isnt html) and (document.activeElement isnt @getEditableNode())

  componentDidUpdate: ->
    if (@props.html != @getEditableNode().innerHTML)
      @getEditableNode().innerHTML = @_htmlForDisplay()

  focus: ->
    @getEditableNode().focus()

  _onChange: (evt) ->
    html = @getEditableNode().innerHTML

    # If we aren't displaying quoted text, add the quoted
    # text to the end of the visible text
    if not @state.editQuotedText
      quoteStart = @_htmlQuotedTextStart()
      html += @props.html.substr(quoteStart)

    if html != @lastHtml
      @props.onChange({target: {value: html}}) if @props.onChange
    @lastHtml = html

  _onToggleQuotedText: ->
    @setState
      editQuotedText: !@state.editQuotedText

  _onPaste: (evt) ->
    html = evt.clipboardData.getData("text/html") ? ""
    if html.length is 0
      text = evt.clipboardData.getData("text/plain") ? ""
      if text.length > 0
        evt.preventDefault()
        cleanHtml = text
      else
    else
      evt.preventDefault()
      cleanHtml = @_sanitizeHtml(html)

    document.execCommand("insertHTML", false, cleanHtml)
    return false

  # This is used primarily when pasting text in
  _sanitizeHtml: (html) ->
    cleanHtml = sanitizeHtml html.replace(/\n/g, "<br/>"),
      allowedTags: ['p', 'b', 'i', 'em', 'strong', 'a', 'br', 'img', 'ul', 'ol', 'li', 'strike']
      allowedAttributes:
        a: ['href', 'name']
        img: ['src', 'alt']
      transformTags:
        h1: "p"
        h2: "p"
        h3: "p"
        h4: "p"
        h5: "p"
        h6: "p"
        div: "p"
        pre: "p"
        blockquote: "p"
        table: "p"

    cleanHtml.replace(/<p>/gi, "").replace(/<\/p>/gi, "<br/><br/>")

  _htmlQuotedTextStart: ->
    @props.html.search(/<[^>]*gmail_quote/)

  _htmlForDisplay: ->
    if @state.editQuotedText
      @props.html
    else
      quoteStart = @_htmlQuotedTextStart()
      @props.html.substr(0, quoteStart) unless quoteStart is -1


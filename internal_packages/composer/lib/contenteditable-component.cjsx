_ = require 'underscore-plus'
React = require 'react'
sanitizeHtml = require 'sanitize-html'

module.exports =
ContenteditableComponent = React.createClass
  render: ->
    <div id="contenteditable"
         ref="editableDif"
         className="scribe native-key-bindings"
         onInput={@_onChange}
         onPaste={@_onPaste}
         tabIndex={@props.tabIndex}
         onBlur={@_onChange}
         contentEditable
         dangerouslySetInnerHTML={{__html: @props.html}}></div>

  shouldComponentUpdate: (nextProps) ->
    html = @getDOMNode().innerHTML
    return (nextProps.html isnt html) and (document.activeElement isnt @getDOMNode())

  componentDidUpdate: ->
    if ( @props.html != @getDOMNode().innerHTML )
      @getDOMNode().innerHTML = @props.html

  focus: ->
    @getDOMNode().focus()

  _onChange: (evt) ->
    html = @getDOMNode().innerHTML
    if (@props.onChange && html != @lastHtml)
      evt.target = { value: html }
      @props.onChange(evt)
    @lastHtml = html

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

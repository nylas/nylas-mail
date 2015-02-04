_ = require 'underscore-plus'
React = require 'react'

module.exports =
ContenteditableComponent = React.createClass
  render: ->
    <div id="contenteditable"
      className="scribe native-key-bindings"
      onInput={@onChange}
      tabIndex={@props.tabIndex}
      onBlur={@onChange}
      contentEditable
      dangerouslySetInnerHTML={{__html: @props.html}}></div>

  shouldComponentUpdate: (nextProps) ->
    html = @getDOMNode().innerHTML
    return (nextProps.html isnt html) and (document.activeElement isnt @getDOMNode())

  registerToolbar: (element) ->

  componentDidUpdate: ->
    if ( @props.html != @getDOMNode().innerHTML )
      @getDOMNode().innerHTML = @props.html

  focus: ->
    @getDOMNode().focus()

  onChange: (evt) ->
    html = @getDOMNode().innerHTML
    if (@props.onChange && html != @lastHtml)
      evt.target = { value: html }
      @props.onChange(evt)
    @lastHtml = html

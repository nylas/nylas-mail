React = require 'react/addons'
_ = require 'underscore'
{CompositeDisposable} = require 'event-kit'

class QuotedTextToggleButton extends React.Component
  @displayName: "QuotedTextToggleButton"

  render: =>
    style =
      'backgroundColor': '#f7f7f7'
      'borderRadius': 5
      'padding': 7
      'display': 'inline-block'
      'paddingTop': 0
      'paddingBottom': '2'
      'color': '#333'
      'border': '1px solid #eee'
      'lineHeight': '16px'
      'marginBottom': 10
      'marginLeft': 15
      'cursor': 'pointer'

    if @props.hidden
      style.display = 'none'

    if @props.toggled
      content = 'Hide Quoted Text'
    else
      content = "•••"

    <a onClick={@props.onClick} style={style}>{content}</a>

module.exports = QuotedTextToggleButton

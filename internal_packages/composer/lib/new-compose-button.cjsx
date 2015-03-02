React = require 'react'
{Message, Actions, NamespaceStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

module.exports =
NewComposeButton = React.createClass
  render: ->
    <button className="btn btn-compose" onClick={@_onNewCompose}>
      <RetinaImg name="toolbar-compose.png" style={position:'relative', top:-3, left: 3}/>
    </button>

  _onNewCompose: -> Actions.composeNewBlankDraft()

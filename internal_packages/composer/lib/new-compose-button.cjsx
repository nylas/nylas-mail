React = require 'react'
{Message, Actions, NamespaceStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

module.exports =
NewComposeButton = React.createClass
  render: ->
    <button style={order: -100} className="btn btn-toolbar" onClick={@_onNewCompose}>
      <RetinaImg name="toolbar-compose.png"/>
    </button>

  _onNewCompose: -> Actions.composeNewBlankDraft()

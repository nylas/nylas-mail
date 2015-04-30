React = require 'react'
{Message, Actions, NamespaceStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

class NewComposeButton extends React.Component
  render: =>
    <button style={order: 101}
            className="btn btn-toolbar"
            data-tooltip="Compose new message"
            onClick={@_onNewCompose}>
      <RetinaImg name="toolbar-compose.png"/>
    </button>

  _onNewCompose: => Actions.composeNewBlankDraft()

module.exports = NewComposeButton

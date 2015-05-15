React = require 'react'
{Message, Actions, NamespaceStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class NewComposeButton extends React.Component
  @displayName: 'NewComposeButton'

  render: =>
    <button style={order: 101}
            className="btn btn-toolbar"
            data-tooltip="Compose new message"
            onClick={@_onNewCompose}>
      <RetinaImg name="toolbar-compose.png"/>
    </button>

  _onNewCompose: => Actions.composeNewBlankDraft()

module.exports = NewComposeButton

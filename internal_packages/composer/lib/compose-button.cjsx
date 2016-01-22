React = require 'react'
{Message, Actions, AccountStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ComposeButton extends React.Component
  @displayName: 'ComposeButton'

  render: =>
    <button className="btn btn-toolbar item-compose"
            title="Compose new message"
            onClick={@_onNewCompose}>
      <RetinaImg name="toolbar-compose.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onNewCompose: => Actions.composeNewBlankDraft()

module.exports = ComposeButton

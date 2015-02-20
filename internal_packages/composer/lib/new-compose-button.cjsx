React = require 'react'
{Message, Actions, NamespaceStore} = require 'inbox-exports'

module.exports =
NewComposeButton = React.createClass
  render: ->
    <button className="btn btn-compose" onClick={@_onNewCompose}>
        <i className="fa fa-pencil"></i>&nbsp;Compose
    </button>

  _onNewCompose: -> Actions.composeNewBlankDraft()

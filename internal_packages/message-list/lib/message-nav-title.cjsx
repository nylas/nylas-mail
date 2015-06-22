
_ = require 'underscore'
_str = require 'underscore.string'
React = require 'react'
{Actions, FocusedTagStore} = require 'nylas-exports'

class MessageNavTitle extends React.Component
  @displayName: 'MessageNavTitle'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unsubscriber = FocusedTagStore.listen @_onChange

  componentWillUnmount: =>
    @_unsubscriber() if @_unsubscriber

  render: =>
    if @state.tagId
      title = "Back to #{_str.titleize(@state.tagId)}"
    else
      title = "Back"

    <div onClick={ -> Actions.popSheet() }
         className="message-nav-title">{title}</div>

  _onChange: => _.defer =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    tagId: FocusedTagStore.tagId()

module.exports = MessageNavTitle

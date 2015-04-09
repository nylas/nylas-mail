_ = require 'underscore-plus'
React = require 'react'
{FocusedContentStore} = require 'inbox-exports'

module.exports =
MessageSubjectItem = React.createClass
  displayName: 'MessageSubjectItem'

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_unsubscriber = FocusedContentStore.listen @_onChange

  componentWillUnmount: ->
    @_unsubscriber() if @_unsubscriber

  render: ->
    <div className="message-toolbar-subject">{@state.thread?.subject}</div>

  _onChange: -> _.defer =>
    return unless @isMounted()
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    thread: FocusedContentStore.focused('thread')


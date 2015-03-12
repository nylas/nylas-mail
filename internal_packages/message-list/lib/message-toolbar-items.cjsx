React = require 'react'
{Actions, ThreadStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

# Note: These always have a thread, but only sometimes get a
# message, depending on where in the UI they are being displayed.

ReplyButton = React.createClass
  render: ->
    <button className="btn btn-toolbar"
            data-tooltip="Reply"
            onClick={@_onReply}>
      <RetinaImg name="toolbar-reply.png" />
    </button>

  _onReply: (e) ->
    Actions.composeReply(threadId: ThreadStore.selectedId())
    e.stopPropagation()

ReplyAllButton = React.createClass
  render: ->
    <button className="btn btn-toolbar"
            data-tooltip="Reply All"
            onClick={@_onReplyAll}>
      <RetinaImg name="toolbar-reply-all.png" />
    </button>

  _onReplyAll: (e) ->
    Actions.composeReplyAll(threadId: ThreadStore.selectedId())
    e.stopPropagation()

ForwardButton = React.createClass
  render: ->
    <button className="btn btn-toolbar"
            data-tooltip="Forward"
            onClick={@_onForward}>
      <RetinaImg name="toolbar-forward.png" />
    </button>

  _onForward: (e) ->
    Actions.composeForward(threadId: ThreadStore.selectedId())
    e.stopPropagation()

ArchiveButton = React.createClass
  render: ->
    <button className="btn btn-toolbar"
            data-tooltip="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" />
    </button>

  _onArchive: (e) ->
    # Calling archive() sends an Actions.queueTask with an archive task
    # TODO Turn into an Action
    ThreadStore.selectedThread().archive()
    e.stopPropagation()


module.exports = React.createClass
  getInitialState: ->
    threadIsSelected: false

  render: ->
    classes = React.addons.classSet
      "message-toolbar-items": true
      "hidden": !@state.threadIsSelected

    <div className={classes}>
      <div className="message-toolbar-items-inner">
        <ReplyButton />
        <ReplyAllButton />
        <ForwardButton />
        <ArchiveButton />
      </div>
    </div>

  componentDidMount: ->
    @_unsubscribers = []
    @_unsubscribers.push ThreadStore.listen @_onChange

  componentWillUnmount: ->
    unsubscribe() for unsubscribe in @_unsubscribers

  _onChange: ->
    @setState
      threadIsSelected: ThreadStore.selectedId()?

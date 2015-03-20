React = require 'react'
{Actions, ThreadStore, Utils} = require 'inbox-exports'
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
    return unless Utils.nodeIsVisible(e.currentTarget)
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
    return unless Utils.nodeIsVisible(e.currentTarget)
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
    return unless Utils.nodeIsVisible(e.currentTarget)
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
    return unless Utils.nodeIsVisible(e.currentTarget)
    # Calling archive() sends an Actions.queueTask with an archive task
    # TODO Turn into an Action
    ThreadStore.selectedThread().archive()
    e.stopPropagation()


module.exports = React.createClass
  getInitialState: ->
    threadIsSelected: ThreadStore.selectedId()?

  render: ->
    classes = React.addons.classSet
      "message-toolbar-items": true
      "hidden": !@state.threadIsSelected

    <div className={classes}>
      <ArchiveButton />
    </div>

  componentDidMount: ->
    @_unsubscribers = []
    @_unsubscribers.push ThreadStore.listen @_onChange

  componentWillUnmount: ->
    unsubscribe() for unsubscribe in @_unsubscribers

  _onChange: ->
    @setState
      threadIsSelected: ThreadStore.selectedId()?

React = require "react/addons"
classNames = require 'classnames'
ThreadListStore = require './thread-list-store'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
 TaskFactory,
 CategoryStore,
 FocusedContentStore,
 FocusedMailViewStore} = require "nylas-exports"

class ThreadBulkArchiveButton extends React.Component
  @displayName: 'ThreadBulkArchiveButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    return false unless mailViewFilter?.canArchiveThreads()

    <button style={order:-107}
            className="btn btn-toolbar"
            data-tooltip="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onArchive: =>
    task = TaskFactory.taskForArchiving
      threads: @props.selection.items(),
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)

class ThreadBulkTrashButton extends React.Component
  @displayName: 'ThreadBulkTrashButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    mailViewFilter = FocusedMailViewStore.mailView()
    return false unless mailViewFilter?.canTrashThreads()

    <button style={order:-106}
            className="btn btn-toolbar"
            data-tooltip="Move to Trash"
            onClick={@_onRemove}>
      <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onRemove: =>
    task = TaskFactory.taskForMovingToTrash
      threads: @props.selection.items(),
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)


class ThreadBulkStarButton extends React.Component
  @displayName: 'ThreadBulkStarButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    <button style={order:-104}
            className="btn btn-toolbar"
            data-tooltip="Star"
            onClick={@_onStar}>
      <RetinaImg name="toolbar-star.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onStar: =>
    task = TaskFactory.taskForInvertingStarred(threads: @props.selection.items())
    Actions.queueTask(task)


class ThreadBulkToggleUnreadButton extends React.Component
  @displayName: 'ThreadBulkToggleUnreadButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: =>
    canMarkUnread = not @props.selection.items().every (s) -> s.unread is true
    fragment = if canMarkUnread then "unread" else "read"

    <button style={order:-105}
            className="btn btn-toolbar"
            data-tooltip="Mark as #{fragment}"
            onClick={@_onClick}>
      <RetinaImg name="icon-toolbar-markas#{fragment}@2x.png"
                 mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onClick: =>
    task = TaskFactory.taskForInvertingUnread(threads: @props.selection.items())
    Actions.queueTask(task)


ThreadNavButtonMixin =
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_unsubscribe = ThreadListStore.listen @_onStoreChange
    @_unsubscribe_focus = FocusedContentStore.listen @_onStoreChange

  isFirstThread: ->
    selectedId = FocusedContentStore.focusedId('thread')
    ThreadListStore.view().get(0)?.id is selectedId

  isLastThread: ->
    selectedId = FocusedContentStore.focusedId('thread')

    lastIndex = ThreadListStore.view().count() - 1
    ThreadListStore.view().get(lastIndex)?.id is selectedId

  componentWillUnmount: ->
    @_unsubscribe()
    @_unsubscribe_focus()

  _onStoreChange: ->
    @setState @_getStateFromStores()


DownButton = React.createClass
  displayName: 'DownButton'
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick}>
      <RetinaImg name="toolbar-down-arrow.png" mode={RetinaImg.Mode.ContentIsMask} />
    </div>

  _classSet: ->
    classNames
      "btn-icon": true
      "message-toolbar-arrow": true
      "down": true
      "disabled": @state.disabled

  _onClick: ->
    return if @state.disabled
    atom.commands.dispatch(document.body, 'core:next-item')

  _getStateFromStores: ->
    disabled: @isLastThread()

UpButton = React.createClass
  displayName: 'UpButton'
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick}>
      <RetinaImg name="toolbar-up-arrow.png" mode={RetinaImg.Mode.ContentIsMask} />
    </div>

  _classSet: ->
    classNames
      "btn-icon": true
      "message-toolbar-arrow": true
      "up": true
      "disabled": @state.disabled

  _onClick: ->
    return if @state.disabled
    atom.commands.dispatch(document.body, 'core:previous-item')

  _getStateFromStores: ->
    disabled: @isFirstThread()

UpButton.containerRequired = false
DownButton.containerRequired = false

module.exports = {
  DownButton,
  UpButton,
  ThreadBulkArchiveButton,
  ThreadBulkTrashButton,
  ThreadBulkStarButton,
  ThreadBulkToggleUnreadButton
}

_ = require 'underscore'
React = require "react"
classNames = require 'classnames'
ThreadListStore = require './thread-list-store'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
 TaskFactory,
 AccountStore,
 CategoryStore,
 FocusedContentStore,
 FocusedPerspectiveStore} = require "nylas-exports"

class ArchiveButton extends React.Component
  @displayName: 'ArchiveButton'
  @containerRequired: false

  @propTypes:
    items: React.PropTypes.array.isRequired

  render: ->
    canArchiveThreads = FocusedPerspectiveStore.current().canArchiveThreads(@props.items)
    return <span /> unless canArchiveThreads

    <button
      tabIndex={-1}
      style={order:-107}
      className="btn btn-toolbar"
      title="Archive"
      onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onArchive: (event) =>
    tasks = TaskFactory.tasksForArchiving
      threads: @props.items
    Actions.queueTasks(tasks)
    Actions.popSheet()
    event.stopPropagation()
    return

class TrashButton extends React.Component
  @displayName: 'TrashButton'
  @containerRequired: false

  @propTypes:
    items: React.PropTypes.array.isRequired

  render: ->
    canTrashThreads = FocusedPerspectiveStore.current().canTrashThreads(@props.items)
    return <span /> unless canTrashThreads

    <button tabIndex={-1}
            style={order:-106}
            className="btn btn-toolbar"
            title="Move to Trash"
            onClick={@_onRemove}>
      <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onRemove: (event) =>
    tasks = TaskFactory.tasksForMovingToTrash
      threads: @props.items
    Actions.queueTasks(tasks)
    Actions.popSheet()
    event.stopPropagation()
    return


class ToggleStarredButton extends React.Component
  @displayName: 'ToggleStarredButton'
  @containerRequired: false

  @propTypes:
    items: React.PropTypes.array.isRequired

  render: ->
    postClickStarredState = _.every @props.items, (t) -> t.starred is false
    title = "Remove stars from all"
    imageName = "toolbar-star-selected.png"

    if postClickStarredState
      title = "Star all"
      imageName = "toolbar-star.png"

    <button tabIndex={-1}
            style={order:-104}
            className="btn btn-toolbar"
            title={title}
            onClick={@_onStar}>
      <RetinaImg name={imageName} mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onStar: (event) =>
    task = TaskFactory.taskForInvertingStarred(threads: @props.items)
    Actions.queueTask(task)
    event.stopPropagation()
    return


class ToggleUnreadButton extends React.Component
  @displayName: 'ToggleUnreadButton'
  @containerRequired: false

  @propTypes:
    items: React.PropTypes.array.isRequired

  render: =>
    postClickUnreadState = _.every @props.items, (t) -> _.isMatch(t, {unread: false})
    fragment = if postClickUnreadState then "unread" else "read"

    <button tabIndex={-1}
            style={order:-105}
            className="btn btn-toolbar"
            title="Mark as #{fragment}"
            onClick={@_onClick}>
      <RetinaImg name="toolbar-markas#{fragment}.png"
                 mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onClick: (event) =>
    task = TaskFactory.taskForInvertingUnread(threads: @props.items)
    Actions.queueTask(task)
    Actions.popSheet()
    event.stopPropagation()
    return

ThreadNavButtonMixin =
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_unsubscribe = ThreadListStore.listen @_onStoreChange
    @_unsubscribe_focus = FocusedContentStore.listen @_onStoreChange

  isFirstThread: ->
    selectedId = FocusedContentStore.focusedId('thread')
    ThreadListStore.dataSource().get(0)?.id is selectedId

  isLastThread: ->
    selectedId = FocusedContentStore.focusedId('thread')

    lastIndex = ThreadListStore.dataSource().count() - 1
    ThreadListStore.dataSource().get(lastIndex)?.id is selectedId

  componentWillUnmount: ->
    @_unsubscribe()
    @_unsubscribe_focus()

  _onStoreChange: ->
    @setState @_getStateFromStores()


DownButton = React.createClass
  displayName: 'DownButton'
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick} title="Next thread">
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
    NylasEnv.commands.dispatch(document.body, 'core:next-item')
    return

  _getStateFromStores: ->
    disabled: @isLastThread()

UpButton = React.createClass
  displayName: 'UpButton'
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick} title="Previous thread">
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
    NylasEnv.commands.dispatch(document.body, 'core:previous-item')
    return

  _getStateFromStores: ->
    disabled: @isFirstThread()

UpButton.containerRequired = false
DownButton.containerRequired = false

module.exports = {
  UpButton,
  DownButton,
  TrashButton,
  ArchiveButton,
  ToggleStarredButton,
  ToggleUnreadButton
}

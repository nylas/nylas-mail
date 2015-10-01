React = require "react/addons"
classNames = require 'classnames'
ThreadListStore = require './thread-list-store'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
 RemoveThreadHelper,
 FocusedContentStore,
 FocusedMailViewStore} = require "nylas-exports"

class ThreadBulkRemoveButton extends React.Component
  @displayName: 'ThreadBulkRemoveButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    focusedMailViewFilter = FocusedMailViewStore.mailView()
    return false unless focusedMailViewFilter?.canRemoveThreads()

    if RemoveThreadHelper.removeType() is RemoveThreadHelper.Type.Archive
      tooltip = "Archive"
      imgName = "toolbar-archive.png"
    else if RemoveThreadHelper.removeType() is RemoveThreadHelper.Type.Trash
      tooltip = "Trash"
      imgName = "toolbar-trash.png"

    <button style={order:-106}
            className="btn btn-toolbar"
            data-tooltip={tooltip}
            onClick={@_onRemove}>
      <RetinaImg name={imgName} mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onRemove: =>
    Actions.removeSelection()


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
    Actions.toggleStarSelection()


class ThreadBulkToggleUnreadButton extends React.Component
  @displayName: 'ThreadBulkToggleUnreadButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  constructor: ->
    @state = @_getStateFromStores()
    super

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push ThreadListStore.listen @_onStoreChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    fragment = if @state.canMarkUnread then "unread" else "read"

    <button style={order:-105}
            className="btn btn-toolbar"
            data-tooltip="Mark as #{fragment}"
            onClick={@_onClick}>
      <RetinaImg name="icon-toolbar-markas#{fragment}@2x.png"
                 mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onClick: =>
    Actions.toggleUnreadSelection()

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: =>
    selections = ThreadListStore.view().selection.items()
    canMarkUnread: not selections.every (s) -> s.unread is true



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

module.exports = {DownButton, UpButton, ThreadBulkRemoveButton, ThreadBulkStarButton, ThreadBulkToggleUnreadButton}

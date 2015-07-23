React = require "react/addons"
classNames = require 'classnames'
ThreadListStore = require './thread-list-store'
{RetinaImg} = require 'nylas-component-kit'
{Actions, FocusedContentStore} = require "nylas-exports"

class ThreadBulkArchiveButton extends React.Component
  @displayName: 'ThreadBulkArchiveButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    <button style={order:-105}
            className="btn btn-toolbar"
            data-tooltip="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onArchive: =>
    Actions.archiveSelection()


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

module.exports = {DownButton, UpButton, ThreadBulkArchiveButton, ThreadBulkStarButton}

React = require "react/addons"
ThreadStore = require './thread-store'
{FocusedThreadStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

ThreadNavButtonMixin =
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_unsubscribe = ThreadStore.listen @_onStoreChange
    @_unsubscribe_focus = FocusedThreadStore.listen @_onStoreChange

  isFirstThread: ->
    selectedId = FocusedThreadStore.threadId()
    ThreadStore.view().get(0)?.id is selectedId

  isLastThread: ->
    selectedId = FocusedThreadStore.threadId()

    lastIndex = ThreadStore.view().count() - 1
    ThreadStore.view().get(lastIndex)?.id is selectedId

  componentWillUnmount: ->
    @_unsubscribe()
    @_unsubscribe_focus()

  _onStoreChange: ->
    @setState @_getStateFromStores()


DownButton = React.createClass
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick}>
      <RetinaImg name="toolbar-down-arrow.png"/>
    </div>

  _classSet: ->
    React.addons.classSet
      "message-toolbar-arrow": true
      "down": true
      "disabled": @state.disabled

  _onClick: ->
    return if @state.disabled
    atom.commands.dispatch(document.body, 'application:next-item')

  _getStateFromStores: ->
    disabled: @isLastThread()

UpButton = React.createClass
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick}>
      <RetinaImg name="toolbar-up-arrow.png"/>
    </div>

  _classSet: ->
    React.addons.classSet
      "message-toolbar-arrow": true
      "up": true
      "disabled": @state.disabled

  _onClick: ->
    return if @state.disabled
    atom.commands.dispatch(document.body, 'application:previous-item')

  _getStateFromStores: ->
    disabled: @isFirstThread()

module.exports = {DownButton, UpButton}

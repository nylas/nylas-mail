React = require "react/addons"
{ThreadStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

ThreadNavButtonMixin =
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_unsubscribe = ThreadStore.listen @_onThreadStoreChange

  componentWillUnmount: ->
    @_unsubscribe()

  _onThreadStoreChange: ->
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
    disabled: ThreadStore.isLastThread()

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
    disabled: ThreadStore.isFirstThread()

module.exports = {DownButton, UpButton}

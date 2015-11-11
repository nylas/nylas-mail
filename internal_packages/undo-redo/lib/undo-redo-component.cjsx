_ = require 'underscore'
path = require 'path'
React = require 'react'
classNames = require 'classnames'
{RetinaImg, TimeoutTransitionGroup} = require 'nylas-component-kit'
{Actions,
Utils,
ComponentRegistry,
UndoRedoStore,
AccountStore} = require 'nylas-exports'

class UndoRedoComponent extends React.Component
  @displayName: 'UndoRedoComponent'

  @containerRequired: false

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @_timeout = null

  _onChange: =>
    @setState(@_getStateFromStores(), =>
      @_setNewTimeout())

  _clearTimeout: =>
    clearTimeout(@_timeout)

  _setNewTimeout: =>
    @_clearTimeout()
    @_timeout = setTimeout (=>
      @_hide()
      return
    ), 3000

  _getStateFromStores: ->
    task = UndoRedoStore.getMostRecentTask()
    show = false
    if task
      show = true

    return {show, task}

  componentWillMount: ->
    @_unsubscribe = UndoRedoStore.listen(@_onChange)

  componentWillUnmount: ->
    @_clearTimeout()
    @_unsubscribe()

  render: =>
    inner = @_renderUndoRedoManager()

    names = classNames
      "undo-redo-manager": true

    <TimeoutTransitionGroup
      className={names}
      leaveTimeout={150}
      enterTimeout={150}
      transitionName="undo-redo-item">
      {inner}
    </TimeoutTransitionGroup>

  _renderUndoRedoManager: =>
    if @state.show
      <div className="undo-redo" onMouseEnter={@_clearTimeout} onMouseLeave={@_setNewTimeout}>
        <div className="undo-redo-message-wrapper">
          {@state.task.description()}
        </div>
        <div className="undo-redo-action-wrapper" onClick={@_onClick}>
          <RetinaImg name="undo-icon@2x.png"
                     mode={RetinaImg.Mode.ContentPreserve}/>
          <span className="undo-redo-action-text">Undo</span>
        </div>
      </div>
    else
      []

  _onClick: =>
    NylasEnv.commands.dispatch(document.querySelector('body'), 'core:undo')
    @_hide()

  _hide: =>
    @setState({show: false, task: null})

module.exports = UndoRedoComponent

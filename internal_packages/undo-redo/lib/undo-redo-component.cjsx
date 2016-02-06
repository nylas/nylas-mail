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
    @_timeout = null
    @state = @_getStateFromStores()
    @_ensureTimeout(@state)

  _clearTimeout: =>
    clearTimeout(@_timeout)
    @_timeout = null

  _ensureTimeout: (state = @state) =>
    if @_timeout
      @_clearTimeout()
    if state.show
      @_timeout = setTimeout(@_hide, 3000)

  _getStateFromStores: ->
    tasks = UndoRedoStore.getMostRecent()
    show = tasks?
    return {show, tasks}

  componentWillMount: ->
    @_unsubscribe = UndoRedoStore.listen =>
      nextState = @_getStateFromStores()
      @setState(nextState)
      @_ensureTimeout(nextState)

  componentWillUnmount: ->
    @_clearTimeout()
    @_unsubscribe()

  render: =>
    classes = classNames
      "undo-redo-manager": true

    <TimeoutTransitionGroup
      className={classes}
      leaveTimeout={150}
      enterTimeout={150}
      transitionName="undo-redo-item">
      {@_renderUndoRedoManager()}
    </TimeoutTransitionGroup>

  _renderUndoRedoManager: =>
    return unless @state.show

    <div className="undo-redo" onMouseEnter={@_onMouseEnter} onMouseLeave={@_onMouseLeave}>
      <div className="undo-redo-message-wrapper">
        {@state.tasks.map((t) -> t.description()).join(', ')}
      </div>
      <div className="undo-redo-action-wrapper" onClick={@_onClick}>
        <RetinaImg name="undo-icon@2x.png"
                   mode={RetinaImg.Mode.ContentIsMask}/>
        <span className="undo-redo-action-text">Undo</span>
      </div>
    </div>

  _onMouseEnter: =>
    @_clearTimeout()

  _onMouseLeave: =>
    @_ensureTimeout(@state)

  _onClick: =>
    NylasEnv.commands.dispatch(document.querySelector('body'), 'core:undo')
    @_hide()

  _hide: =>
    @setState({show: false, tasks: null})

module.exports = UndoRedoComponent

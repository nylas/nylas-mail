_ = require 'underscore'
path = require 'path'
React = require 'react'
ReactDOM = require 'react-dom'
ReactCSSTransitionGroup = require 'react-addons-css-transition-group'
classNames = require 'classnames'
{RetinaImg} = require 'nylas-component-kit'
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

    # Note: we do not set from initial state, because we don't want
    # the last item on the stack to appear, just the next one.
    @state = {}

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

    <ReactCSSTransitionGroup
      className={classes}
      transitionLeaveTimeout={150}
      transitionEnterTimeout={150}
      transitionName="undo-redo-item">
      {@_renderUndoRedoManager()}
    </ReactCSSTransitionGroup>

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
    NylasEnv.commands.dispatch('core:undo')
    @_hide()

  _hide: =>
    @setState({show: false, tasks: null})

module.exports = UndoRedoComponent

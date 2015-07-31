_ = require 'underscore'
path = require 'path'
React = require 'react'
classNames = require 'classnames'
{RetinaImg, TimeoutTransitionGroup} = require 'nylas-component-kit'
{Actions,
Utils,
ComponentRegistry,
UndoRedoStore,
NamespaceStore} = require 'nylas-exports'

class UndoRedoComponent extends React.Component
  @displayName: 'UndoRedoComponent'

  @propTypes:
    task: React.PropTypes.object.isRequired
    show: React.PropTypes.bool

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @_timeout = null

  _onChange: =>
    @setState(@_getStateFromStores(), =>
      @_setNewTimeout())

  _clearTimeout: =>
    clearTimeout(@_timeout)

  _setNewTimeout: =>
    clearTimeout(@_timeout)
    @_timeout = setTimeout (=>
      @_hide()
      return
    ), 3000

  _getStateFromStores: ->
    t = UndoRedoStore.getMostRecentTask()
    s = false
    if t
      s = true

    return {show: s, task: t}

  componentWillMount: ->
    @unsub = UndoRedoStore.listen(@_onChange)

  componentWillUnmount: ->
    @unsub()

  render: =>
    items = [].concat(@_renderUndoRedoManager())

    names = classNames
      "undo-redo-manager": true

    <TimeoutTransitionGroup
      className={names}
      leaveTimeout={450}
      enterTimeout={250}
      transitionName="undo-redo-item">
      {items}
    </TimeoutTransitionGroup>

  _renderUndoRedoManager: =>
    if @state.show
      <div className="undo-redo" onMouseEnter={@_clearTimeout} onMouseLeave={@_setNewTimeout}>
        <div className="undo-redo-message-wrapper">
          <p className="undo-redo-message">{@_formatMessage()}</p>
        </div>
        <div className="undo-redo-action-wrapper" onClick={@_undoTask}>
          <RetinaImg name="undo-icon@2x.png"
                     mode={RetinaImg.Mode.ContentPreserve}/>
          <p className="undo-redo-action-text">Undo</p>
        </div>
      </div>
    else
      []

  _undoTask: =>
    atom.commands.dispatch(document.querySelector('body'), 'core:undo')
    @_hide()

  _formatMessage: =>
    return @state.task.description()

  _hide: =>
    @setState({show: false, task: null})

module.exports = UndoRedoComponent

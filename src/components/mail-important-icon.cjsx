_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 ChangeLabelsTask,
 CategoryStore,
 AccountStore} = require 'nylas-exports'
{KeyCommandsRegion} = require 'nylas-component-kit'

class MailImportantIcon extends React.Component
  @displayName: 'MailImportantIcon'
  @propTypes:
    thread: React.PropTypes.object

  constructor: (@props) ->
    @state = @getState()

  getState: =>
    showing: AccountStore.current()?.usesImportantFlag() and NylasEnv.config.get('core.showImportant')

  componentDidMount: =>
    @subscription = NylasEnv.config.observe 'core.showImportant', =>
      @setState(@getState())

  componentWillUnmount: =>
    @subscription?.dispose()

  shouldComponentUpdate: (nextProps, nextState) =>
    return false if nextProps.thread is @props.thread and @state.showing is nextState.showing
    true

  render: =>
    return false unless @state.showing

    importantId = CategoryStore.getStandardCategory('important')?.id
    return false unless importantId

    isImportant = _.findWhere(@props.thread.labels, {id: importantId})?

    activeClassname = if isImportant then "active" else ""
    <KeyCommandsRegion globalHandlers={@_globalHandlers()}>
      <div className="mail-important-icon #{activeClassname}"
           title={if isImportant then "Mark as unimportant" else "Mark as important"}
           onClick={@_onToggleImportant}></div>
    </KeyCommandsRegion>

  _globalHandlers: =>
    'application:mark-as-important': (e) => @_setImportant(e, true)
    'application:mark-as-unimportant': (e) => @_setImportant(e, false)

  _onToggleImportant: (event) =>
    isImportant = _.findWhere(@props.thread.labels, {id: importantLabel.id})?
    @_setImportant(event, !isImportant)

  _setImportant: (event, important) =>
    importantLabel = CategoryStore.getStandardCategory('important')

    if important
      task = new ChangeLabelsTask(thread: @props.thread, labelsToAdd: [importantLabel], labelsToRemove: [])
    else
      task = new ChangeLabelsTask(thread: @props.thread, labelsToRemove: [importantLabel], labelsToAdd: [])

    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = MailImportantIcon

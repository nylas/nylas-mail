_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 ChangeLabelsTask,
 CategoryStore,
 AccountStore} = require 'nylas-exports'

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
    <div className="mail-important-icon #{activeClassname}"
         title={if isImportant then "Mark as unimportant" else "Mark as important"}
         onClick={@_onToggleImportant}></div>

  _onToggleImportant: (event) =>
    importantLabel = CategoryStore.getStandardCategory('important')
    isImportant = _.findWhere(@props.thread.labels, {id: importantLabel.id})?

    if isImportant
      task = new ChangeLabelsTask(thread: @props.thread, labelsToRemove: [importantLabel], labelsToAdd: [])
    else
      task = new ChangeLabelsTask(thread: @props.thread, labelsToAdd: [importantLabel], labelsToRemove: [])

    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = MailImportantIcon

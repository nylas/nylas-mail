_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{Actions,
 Utils,
 Thread,
 TaskFactory,
 CategoryStore,
 FocusedPerspectiveStore,
 AccountStore} = require 'nylas-exports'

ShowImportantKey = 'core.workspace.showImportant'

class MailImportantIcon extends React.Component
  @displayName: 'MailImportantIcon'
  @propTypes:
    thread: React.PropTypes.object

  constructor: (@props) ->
    @state = @getState()

  getState: =>
    perspective = FocusedPerspectiveStore.current()

    categoryId = null
    visible = false

    for accountId in perspective.accountIds
      account = AccountStore.accountForId(accountId)
      accountImportantId = CategoryStore.getStandardCategory(account, 'important')?.id
      if accountImportantId
        visible = true
      if accountId is @props.thread.accountId
        categoryId = accountImportantId
      break if visible and categoryId

    {visible, categoryId}

  componentDidMount: =>
    @unsubscribe = FocusedPerspectiveStore.listen =>
      @setState(@getState())
    @subscription = NylasEnv.config.observe ShowImportantKey, =>
      @setState(@getState())

  componentWillUnmount: =>
    @unsubscribe?()
    @subscription?.dispose()

  shouldComponentUpdate: (nextProps, nextState) =>
    return false if nextProps.thread is @props.thread and @state.visible is nextState.visible and @state.categoryId is nextState.categoryId
    true

  render: =>
    return false unless @state.visible

    isImportant = @state.categoryId and _.findWhere(@props.thread.labels, {id: @state.categoryId})?

    classes = classNames
      'mail-important-icon': true
      'enabled': @state.categoryId
      'active': isImportant

    if not @state.categoryId
      title = "No important folder / label"
    else if isImportant
      title = "Mark as unimportant"
    else
      title = "Mark as important"

    <div className={classes}}
         title={title}
         onClick={@_onToggleImportant}></div>

  _onToggleImportant: (event) =>
    if @state.categoryId
      isImportant = _.findWhere(@props.thread.categories, {id: @state.categoryId})?
      threads = [@props.thread]

      if !isImportant
        task = TaskFactory.taskForApplyingCategory({threads, category})
      else
        task = TaskFactory.taskForRemovingCategory({threads, category})

      Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = MailImportantIcon

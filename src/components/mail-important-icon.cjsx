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
    showIfAvailableForAnyAccount: React.PropTypes.bool

  constructor: (@props) ->
    @state = @getState()

  getState: (props = @props) =>
    category = null
    visible = false

    if props.showIfAvailableForAnyAccount
      perspective = FocusedPerspectiveStore.current()
      for accountId in perspective.accountIds
        account = AccountStore.accountForId(accountId)
        accountImportant = CategoryStore.getStandardCategory(account, 'important')
        if accountImportant
          visible = true
        if accountId is props.thread.accountId
          category = accountImportant
        break if visible and category
    else
      category = CategoryStore.getStandardCategory(props.thread.accountId, 'important')
      visible = category?

    isImportant = category and _.findWhere(@props.thread.categories, {id: category.id})?

    {visible, category, isImportant}

  componentDidMount: =>
    @unsubscribe = FocusedPerspectiveStore.listen =>
      @setState(@getState())
    @subscription = NylasEnv.config.onDidChange ShowImportantKey, =>
      @setState(@getState())

  componentWillReceiveProps: (nextProps) =>
    @setState(@getState(nextProps))

  componentWillUnmount: =>
    @unsubscribe?()
    @subscription?.dispose()

  shouldComponentUpdate: (nextProps, nextState) =>
    not _.isEqual(nextState, @state)

  render: =>
    return false unless @state.visible

    classes = classNames
      'mail-important-icon': true
      'enabled': @state.category?
      'active': @state.isImportant

    if not @state.category
      title = "No important folder / label"
    else if @state.isImportant
      title = "Mark as unimportant"
    else
      title = "Mark as important"

    <div className={classes}}
         title={title}
         onClick={@_onToggleImportant}></div>

  _onToggleImportant: (event) =>
    {category} = @state

    if category
      isImportant = _.findWhere(@props.thread.categories, {id: category.id})?
      threads = [@props.thread]

      if !isImportant
        task = TaskFactory.taskForApplyingCategory({threads, category})
      else
        task = TaskFactory.taskForRemovingCategory({threads, category})

      Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = MailImportantIcon

_ = require 'underscore'
classNames = require 'classnames'
{React,
 PropTypes,
 Actions,
 Utils,
 Thread,
 ChangeLabelsTask,
 CategoryStore,
 FocusedPerspectiveStore,
 AccountStore} = require 'mailspring-exports'

ShowImportantKey = 'core.workspace.showImportant'

class MailImportantIcon extends React.Component
  @displayName: 'MailImportantIcon'
  @propTypes:
    thread: PropTypes.object
    showIfAvailableForAnyAccount: PropTypes.bool

  constructor: (@props) ->
    @state = @getState()

  getState: (props = @props) =>
    category = null
    visible = false

    if props.showIfAvailableForAnyAccount
      perspective = FocusedPerspectiveStore.current()
      for accountId in perspective.accountIds
        account = AccountStore.accountForId(accountId)
        accountImportant = CategoryStore.getCategoryByRole(account, 'important')
        if accountImportant
          visible = true
        if accountId is props.thread.accountId
          category = accountImportant
        break if visible and category
    else
      category = CategoryStore.getCategoryByRole(props.thread.accountId, 'important')
      visible = category?

    isImportant = category and _.findWhere(props.thread.labels, {id: category.id})?

    {visible, category, isImportant}

  componentDidMount: =>
    @unsubscribe = FocusedPerspectiveStore.listen =>
      @setState(@getState())
    @subscription = AppEnv.config.onDidChange ShowImportantKey, =>
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
      isImportant = _.findWhere(@props.thread.labels, {id: category.id})?

      if !isImportant
        Actions.queueTask(new ChangeLabelsTask({
          labelsToAdd: [category],
          labelsToRemove: [],
          threads: [@props.thread],
          source: "Important Icon",
        }))
      else
        Actions.queueTask(new ChangeLabelsTask({
          labelsToAdd: [],
          labelsToRemove: [category],
          threads: [@props.thread],
          source: "Important Icon",
        }))

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = MailImportantIcon

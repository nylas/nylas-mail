React = require 'react'
_ = require 'underscore'

{Actions,
 AccountStore,
 MailRulesStore,
 MailRulesTemplates,
 TaskQueueStatusStore,
 ReprocessMailRulesTask} = require 'nylas-exports'

{Flexbox,
 EditableList,
 RetinaImg,
 ScrollRegion,
 ScenarioEditor} = require 'nylas-component-kit'

{ActionTemplatesForAccount,
 ConditionTemplatesForAccount} = MailRulesTemplates

class PreferencesMailRules extends React.Component
  @displayName: 'PreferencesMailRules'

  @propTypes:
    accountId: React.PropTypes.string.isRequired

  constructor: (@props) ->
    @state = @stateForAccount(@props.accountId)

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push MailRulesStore.listen @_onRulesChanged
    @_unsubscribers.push TaskQueueStatusStore.listen @_onTasksChanged

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  componentWillReceiveProps: (newProps) =>
    newState = @stateForAccount(newProps.accountId)
    @setState(newState)

  stateForAccount: (accountId) =>
    account = AccountStore.itemWithId(accountId)
    rules = MailRulesStore.rulesForAccountId(accountId)

    return {
      account: account
      rules: rules
      selectedRule: _.findWhere(rules, {id: @state?.selectedRule?.id}) ? rules[0]
      tasks: TaskQueueStatusStore.tasksMatching(ReprocessMailRulesTask, {})
      actionTemplates: ActionTemplatesForAccount(account)
      ConditionTemplates: ConditionTemplatesForAccount(account)
    }

  render: =>
    <div className="container-mail-rules">
      <section>
        <h2>Mail Rules</h2>
        <p>{@state.account?.emailAddress}</p>

        <Flexbox>
          {@_renderList()}
          {@_renderDetail()}
        </Flexbox>

        <div className="platform-note" style={marginTop:30, maxWidth: 600}>
          By default, mail rules are only applied to new mail as it arrives.
          Applying rules to your entire mailbox may take quite a while and
          temporarily degrade performance.
        </div>

        <Flexbox style={marginTop:10, maxWidth: 600}>
          <div>
            <button className="btn" style={float:'right'} onClick={@_onReprocessRules}>
              Process all Mail
            </button>
          </div>
          {@_renderTasks()}
        </Flexbox>
      </section>
    </div>

  _renderList: =>
    <EditableList
      className="rule-list"
      showEditIcon={true}
      items={@state.rules}
      itemContent={@_renderListItemContent}
      onCreateItem={@_onAddRule}
      onDeleteItem={@_onDeleteRule}
      onItemEdited={@_onRuleNameEdited}
      selected={@state.selectedRule}
      onSelectItem={@_onSelectRule} />

  _renderListItemContent: (rule) ->
    if rule.disabled
      return <div className="item-rule-disabled">{rule.name}</div>
    else
      return rule.name
    
  _renderDetail: =>
    rule = @state.selectedRule

    if rule
      <ScrollRegion className="rule-detail">
        {@_renderDetailDisabledNotice()}
        <div className="inner">
          <span>If </span>
          <select value={rule.conditionMode} onChange={@_onRuleConditionModeEdited}>
            <option value='any'>Any</option>
            <option value='all'>All</option>
          </select>
          <span> of the following conditions are met:</span>
          <ScenarioEditor
            instances={rule.conditions}
            templates={@state.ConditionTemplates}
            onChange={ (conditions) => Actions.updateMailRule(rule.id, {conditions}) }
            className="well well-matchers"/>
          <span>Perform the following actions:</span>
          <ScenarioEditor
            instances={rule.actions}
            templates={@state.actionTemplates}
            onChange={ (actions) => Actions.updateMailRule(rule.id, {actions}) }
            className="well well-actions"/>
        </div>
      </ScrollRegion>

    else
      <div className="rule-detail">
        <div className="no-selection">Create a rule or select one to get started</div>
      </div>

  _renderDetailDisabledNotice: =>
    return false unless @state.selectedRule.disabled
    <div className="disabled-reason">
      <button className="btn" onClick={@_onRuleEnabled}>Enable</button>
      This rule has been disabled. Make sure the actions below are valid
      and re-enable the rule.
      <div>({@state.selectedRule.disabledReason})</div>
    </div>

  _renderTasks: =>
    return false if @state.tasks.length is 0

    <div style={flex: 1, paddingLeft:20}>
      { @state.tasks.map (task) ->
        <Flexbox style={alignItems: 'baseline'}>
          <div style={paddingRight: "12px"}>
            <RetinaImg name="sending-spinner.gif" width={18} mode={RetinaImg.Mode.ContentPreserve} />
          </div>
          <div>
            <strong>{AccountStore.itemWithId(task.accountId).emailAddress}</strong>
            {" — #{new Number(task.numberOfImpactedItems()).toLocaleString()} processed..."}
          </div>
          <div style={flex: 1}></div>
          <button className="btn btn-sm" onClick={ => Actions.dequeueTask(task.id) }>Cancel</button>
        </Flexbox>
      }
    </div>

  _onReprocessRules: =>
    needsMessageBodies = =>
      for rule in @state.rules
        for condition in rule.conditions
          if condition.templateKey is 'body'
            return true
      return false

    if needsMessageBodies()
      NylasEnv.showErrorDialog("One or more of your mail rules requires the bodies of messages being processed. These rules can't be run on your entire mailbox.")

    task = new ReprocessMailRulesTask(@state.account.id)
    Actions.queueTask(task)

  _onAddRule: =>
    Actions.addMailRule({accountId: @state.account.id})

  _onSelectRule: (rule, idx) =>
    @setState(selectedRule: rule)

  _onDeleteRule: (rule, idx) =>
    Actions.deleteMailRule(rule.id)

  _onRuleNameEdited: (newName, rule, idx) =>
    Actions.updateMailRule(rule.id, {name: newName})

  _onRuleConditionModeEdited: (event) =>
    Actions.updateMailRule(@state.selectedRule.id, {conditionMode: event.target.value})

  _onRuleEnabled: =>
    Actions.updateMailRule(@state.selectedRule.id, {disabled: false, disabledReason: null})

  _onRulesChanged: =>
    next = @stateForAccount(@props.accountId)
    nextRules = next.rules
    prevRules = @state?.rules || []

    added = _.difference(nextRules, prevRules)
    if added.length is 1
      next.selectedRule = added[0]

    @setState(next)

  _onTasksChanged: =>
    @setState(tasks: TaskQueueStatusStore.tasksMatching(ReprocessMailRulesTask, {}))


module.exports = PreferencesMailRules

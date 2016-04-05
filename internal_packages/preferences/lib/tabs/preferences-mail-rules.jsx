import React from 'react';
import _ from 'underscore';

import {Actions,
  AccountStore,
  MailRulesStore,
  MailRulesTemplates,
  TaskQueueStatusStore,
  ReprocessMailRulesTask} from 'nylas-exports';

import {Flexbox,
  EditableList,
  RetinaImg,
  ScrollRegion,
  ScenarioEditor} from 'nylas-component-kit';

const {
  ActionTemplatesForAccount,
  ConditionTemplatesForAccount,
} = MailRulesTemplates;


class PreferencesMailRules extends React.Component {
  static displayName = 'PreferencesMailRules';

  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._unsubscribers = [];
    this._unsubscribers.push(MailRulesStore.listen(this._onRulesChanged));
    this._unsubscribers.push(TaskQueueStatusStore.listen(this._onTasksChanged));
  }

  componentWillUnmount() {
    this._unsubscribers.forEach(unsubscribe => unsubscribe());
  }

  _getStateFromStores() {
    const accounts = AccountStore.accounts();
    const state = this.state || {};
    let {currentAccount} = state;
    if (!accounts.find(acct => acct === currentAccount)) {
      currentAccount = accounts[0];
    }
    const rules = MailRulesStore.rulesForAccountId(currentAccount.accountId);
    const selectedRule = this.state && this.state.selectedRule ? _.findWhere(rules, {id: this.state.selectedRule.id}) : rules[0];

    return {
      accounts: accounts,
      currentAccount: currentAccount,
      rules: rules,
      selectedRule: selectedRule,
      tasks: TaskQueueStatusStore.tasksMatching(ReprocessMailRulesTask, {}),
      actionTemplates: ActionTemplatesForAccount(currentAccount),
      conditionTemplates: ConditionTemplatesForAccount(currentAccount),
    }
  }

  _onSelectAccount = (event) => {
    const accountId = event.target.value;
    const currentAccount = this.state.accounts.find(acct => acct.accountId === accountId);
    this.setState({currentAccount: currentAccount}, () => {
      this.setState(this._getStateFromStores())
    });
  }

  _onReprocessRules = () => {
    const needsMessageBodies = () => {
      for (const rule of this.state.rules) {
        for (const condition of rule.conditions) {
          if (condition.templateKey === 'body') {
            return true;
          }
        }
      }
      return false;
    }

    if (needsMessageBodies()) {
      NylasEnv.showErrorDialog("One or more of your mail rules requires the bodies of messages being processed. These rules can't be run on your entire mailbox.");
    }

    const task = new ReprocessMailRulesTask(this.state.currentAccount.accountId)
    Actions.queueTask(task);
  }

  _onAddRule = () => {
    Actions.addMailRule({accountId: this.state.currentAccount.accountId});
  }

  _onSelectRule = (rule) => {
    this.setState({selectedRule: rule});
  }

  _onReorderRule = (rule, newIdx) => {
    Actions.reorderMailRule(rule.id, newIdx);
  }

  _onDeleteRule = (rule) => {
    Actions.deleteMailRule(rule.id);
  }

  _onRuleNameEdited = (newName, rule) => {
    Actions.updateMailRule(rule.id, {name: newName});
  }

  _onRuleConditionModeEdited = (event) => {
    Actions.updateMailRule(this.state.selectedRule.id, {conditionMode: event.target.value});
  }

  _onRuleEnabled = () => {
    Actions.updateMailRule(this.state.selectedRule.id, {disabled: false, disabledReason: null});
  }

  _onRulesChanged = () => {
    const next = this._getStateFromStores();
    const nextRules = next.rules;
    const prevRules = this.state.rules ? this.state.rules : [];

    const added = _.difference(nextRules, prevRules);
    if (added.length === 1) {
      next.selectedRule = added[0];
    }

    this.setState(next);
  }

  _onTasksChanged = () => {
    this.setState({tasks: TaskQueueStatusStore.tasksMatching(ReprocessMailRulesTask, {})})
  }

  _renderAccountPicker() {
    const options = this.state.accounts.map(account =>
      <option value={account.accountId} key={account.accountId}>{account.emailAddress}</option>
    );

    return (
      <select
        value={this.state.currentAccount.accountId}
        onChange={this._onSelectAccount}
        style={{margin: 0}} >
        {options}
      </select>
    );
  }

  _renderMailRules() {
    if (this.state.rules.length === 0) {
      return (
        <div className="empty-list">
          <RetinaImg
            className="icon-mail-rules"
            name="rules-big.png"
            mode={RetinaImg.Mode.ContentDark} />
          <h2>No rules</h2>
          <button className="btn btn-small" onMouseDown={this._onAddRule}>
            Create a new rule
          </button>
        </div>
      );
    }
    return (
      <Flexbox>
        <EditableList
          showEditIcon
          className="rule-list"
          items={this.state.rules}
          itemContent={this._renderListItemContent}
          onCreateItem={this._onAddRule}
          onReorderItem={this._onReorderRule}
          onDeleteItem={this._onDeleteRule}
          onItemEdited={this._onRuleNameEdited}
          selected={this.state.selectedRule}
          onSelectItem={this._onSelectRule} />
        {this._renderDetail()}
      </Flexbox>
    );
  }

  _renderListItemContent(rule) {
    if (rule.disabled) {
      return (<div className="item-rule-disabled">{rule.name}</div>);
    }
    return rule.name;
  }

  _renderDetail() {
    const rule = this.state.selectedRule;

    if (rule) {
      return (
        <ScrollRegion className="rule-detail">
          {this._renderDetailDisabledNotice()}
          <div className="inner">
            <span>If </span>
            <select value={rule.conditionMode} onChange={this._onRuleConditionModeEdited}>
              <option value="any">Any</option>
              <option value="all">All</option>
            </select>
            <span> of the following conditions are met:</span>
            <ScenarioEditor
              instances={rule.conditions}
              templates={this.state.conditionTemplates}
              onChange={ (conditions) => Actions.updateMailRule(rule.id, {conditions}) }
              className="well well-matchers"/>
            <span>Perform the following actions:</span>
            <ScenarioEditor
              instances={rule.actions}
              templates={this.state.actionTemplates}
              onChange={ (actions) => Actions.updateMailRule(rule.id, {actions}) }
              className="well well-actions"/>
          </div>
        </ScrollRegion>
      );
    }

    return (
      <div className="rule-detail">
        <div className="no-selection">Create a rule or select one to get started</div>
      </div>
    );
  }

  _renderDetailDisabledNotice() {
    if (!this.state.selectedRule.disabled) return false;
    return (
      <div className="disabled-reason">
        <button className="btn" onClick={this._onRuleEnabled}>Enable</button>
        This rule has been disabled. Make sure the actions below are valid
        and re-enable the rule.
        <div>({this.state.selectedRule.disabledReason})</div>
      </div>
    );
  }

  _renderTasks() {
    if (this.state.tasks.length === 0) return false;
    return (
      <div style={{flex: 1, paddingLeft: 20}}>
        {this.state.tasks.map((task) => {
          return (
            <Flexbox style={{alignItems: 'baseline'}}>
              <div style={{paddingRight: "12px"}}>
                <RetinaImg name="sending-spinner.gif" width={18} mode={RetinaImg.Mode.ContentPreserve} />
              </div>
              <div>
                <strong>{AccountStore.accountForId(task.accountId).emailAddress}</strong>
                {` — ${Number(task.numberOfImpactedItems()).toLocaleString()} processed...`}
              </div>
              <div style={{flex: 1}}></div>
              <button className="btn btn-sm" onClick={() => Actions.dequeueTask(task.id) }>Cancel</button>
            </Flexbox>
          );
        })}
      </div>
    );
  }

  render() {
    return (
      <div className="container-mail-rules">
        <section>
          <Flexbox className="container-dropdown">
            <div>Account:</div>
            <div className="dropdown">{this._renderAccountPicker()}</div>
          </Flexbox>
          <p>Rules only apply to the selected account.</p>

          {this._renderMailRules()}

          <Flexbox style={{marginTop: 40, maxWidth: 600}}>
            <div>
              <button className="btn" style={{float: 'right'}} onClick={this._onReprocessRules}>
                Process all mail
              </button>
            </div>
            {this._renderTasks()}
          </Flexbox>

          <p style={{marginTop: 10}}>
            By default, mail rules are only applied to new mail as it arrives.
            Applying rules to your entire mailbox may take a long time and
            degrade performance.
          </p>
        </section>
      </div>
    );
  }

}

export default PreferencesMailRules;

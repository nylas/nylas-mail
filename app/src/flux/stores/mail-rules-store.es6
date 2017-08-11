import NylasStore from 'nylas-store';
import _ from 'underscore';
import TaskQueue from './task-queue';
import ReprocessMailRulesTask from '../tasks/reprocess-mail-rules-task';
import Utils from '../models/utils';
import Actions from '../actions';

import {ConditionMode, ConditionTemplates, ActionTemplates} from '../../mail-rules-templates';

const RulesJSONKey = "MailRules-V2"

class MailRulesStore extends NylasStore {
  constructor() {
    super();

    this._rules = [];
    try {
      const txt = window.localStorage.getItem(RulesJSONKey);
      if (txt) {
        this._rules = JSON.parse(txt);
      }
    } catch (err) {
      console.warn("Could not load saved mail rules", err);
    }

    this.listenTo(Actions.addMailRule, this._onAddMailRule);
    this.listenTo(Actions.deleteMailRule, this._onDeleteMailRule);
    this.listenTo(Actions.reorderMailRule, this._onReorderMailRule);
    this.listenTo(Actions.updateMailRule, this._onUpdateMailRule);
    this.listenTo(Actions.disableMailRule, this._onDisableMailRule);
  }

  rules() {
    return this._rules;
  }

  rulesForAccountId(accountId) {
    return this._rules.filter((f) => f.accountId === accountId);
  }

  disabledRules(accountId) {
    return this._rules.filter((f) => f.accountId === accountId && f.disabled);
  }

  _onDeleteMailRule = (id) => {
    this._rules = this._rules.filter((f) => f.id !== id);
    this._saveMailRules();
    this.trigger();
  }

  _onReorderMailRule = (id, newIdx) => {
    const currentIdx = _.findIndex(this._rules, _.matcher({id}))
    if (currentIdx === -1) {
      return;
    }
    const rule = this._rules[currentIdx];
    this._rules.splice(currentIdx, 1);
    this._rules.splice(newIdx, 0, rule);
    this._saveMailRules();
    this.trigger();
  }

  _onAddMailRule = (properties) => {
    const defaults = {
      id: Utils.generateTempId(),
      name: "Untitled Rule",
      conditionMode: ConditionMode.All,
      conditions: [ConditionTemplates[0].createDefaultInstance()],
      actions: [ActionTemplates[0].createDefaultInstance()],
      disabled: false,
    };

    if (!properties.accountId) {
      throw new Error("AddMailRule: you must provide an account id.");
    }

    this._rules.push(Object.assign(defaults, properties));
    this._saveMailRules();
    this.trigger();
  }

  _onUpdateMailRule = (id, properties) => {
    const existing = this._rules.find(f => id === f.id);
    Object.assign(existing, properties);
    this._saveMailRules();
    this.trigger();
  }

  _onDisableMailRule = (id, reason) => {
    const existing = this._rules.find(f => id === f.id);
    if (!existing || existing.disabled === true) {
      return;
    }

    // Disable the task
    existing.disabled = true;
    existing.disabledReason = reason;
    this._saveMailRules();

    // Cancel all bulk processing jobs
    for (const task of TaskQueue.findTasks(ReprocessMailRulesTask, {})) {
      Actions.cancelTask(task);
    }

    this.trigger();
  }

  _saveMailRules() {
    this._saveMailRulesDebounced = this._saveMailRulesDebounced || _.debounce(() => {
      window.localStorage.setItem(RulesJSONKey, JSON.stringify(this._rules));
    }, 1000);
    this._saveMailRulesDebounced();
  }
}

export default new MailRulesStore()

import MailspringStore from 'mailspring-store';
import _ from 'underscore';
import Utils from '../models/utils';
import Actions from '../actions';
import Thread from '../models/thread';
import Message from '../models/message';
import DatabaseStore from '../stores/database-store';
import CategoryStore from '../stores/category-store';
import MailRulesProcessor from '../../mail-rules-processor';

import { ConditionMode, ConditionTemplates, ActionTemplates } from '../../mail-rules-templates';

const RulesJSONKey = 'MailRules-V2';

class MailRulesStore extends MailspringStore {
  constructor() {
    super();

    this._reprocessing = {};
    this._rules = [];
    try {
      const txt = window.localStorage.getItem(RulesJSONKey);
      if (txt) {
        this._rules = JSON.parse(txt);
      }
    } catch (err) {
      console.warn('Could not load saved mail rules', err);
    }

    this.listenTo(Actions.addMailRule, this._onAddMailRule);
    this.listenTo(Actions.deleteMailRule, this._onDeleteMailRule);
    this.listenTo(Actions.reorderMailRule, this._onReorderMailRule);
    this.listenTo(Actions.updateMailRule, this._onUpdateMailRule);
    this.listenTo(Actions.disableMailRule, this._onDisableMailRule);
    this.listenTo(Actions.startReprocessingMailRules, this._onStartReprocessing);
    this.listenTo(Actions.stopReprocessingMailRules, this._onStopReprocessing);
  }

  rules() {
    return this._rules;
  }

  rulesForAccountId(accountId) {
    return this._rules.filter(f => f.accountId === accountId);
  }

  disabledRules(accountId) {
    return this._rules.filter(f => f.accountId === accountId && f.disabled);
  }

  reprocessState() {
    return this._reprocessing;
  }

  _onDeleteMailRule = id => {
    this._rules = this._rules.filter(f => f.id !== id);
    this._saveMailRules();
    this.trigger();
  };

  _onReorderMailRule = (id, newIdx) => {
    const currentIdx = this._rules.findIndex(r => r.id === id);
    if (currentIdx === -1) {
      return;
    }
    const rule = this._rules[currentIdx];
    this._rules.splice(currentIdx, 1);
    this._rules.splice(newIdx, 0, rule);
    this._saveMailRules();
    this.trigger();
  };

  _onAddMailRule = properties => {
    const defaults = {
      id: Utils.generateTempId(),
      name: 'Untitled Rule',
      conditionMode: ConditionMode.All,
      conditions: [ConditionTemplates[0].createDefaultInstance()],
      actions: [ActionTemplates[0].createDefaultInstance()],
      disabled: false,
    };

    if (!properties.accountId) {
      throw new Error('AddMailRule: you must provide an account id.');
    }

    this._rules.push(Object.assign(defaults, properties));
    this._saveMailRules();
    this.trigger();
  };

  _onUpdateMailRule = (id, properties) => {
    const existing = this._rules.find(f => id === f.id);
    Object.assign(existing, properties);
    this._saveMailRules();
    this.trigger();
  };

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
    this._reprocessing = {};

    this.trigger();
  };

  _saveMailRules() {
    this._saveMailRulesDebounced =
      this._saveMailRulesDebounced ||
      _.debounce(() => {
        window.localStorage.setItem(RulesJSONKey, JSON.stringify(this._rules));
      }, 1000);
    this._saveMailRulesDebounced();
  }

  // Reprocessing Existing Mail

  _onStartReprocessing = aid => {
    const inboxCategory = CategoryStore.getCategoryByRole(aid, 'inbox');
    if (!inboxCategory) {
      AppEnv.showErrorDialog(
        `Sorry, this account does not appear to have an inbox folder so this feature is disabled.`
      );
      return;
    }

    this._reprocessing[aid] = {
      count: 1,
      lastTimestamp: null,
      inboxCategoryId: inboxCategory.id,
    };
    this._reprocessSome(aid);
    this.trigger();
  };

  _onStopReprocessing = aid => {
    delete this._reprocessing[aid];
    this.trigger();
  };

  _reprocessSome = (accountId, callback) => {
    if (!this._reprocessing[accountId]) {
      return;
    }
    const { lastTimestamp, inboxCategoryId } = this._reprocessing[accountId];

    // Fetching threads first, and then getting their messages allows us to use
    // The same indexes as the thread list / message list in the app

    // Note that we look for "50 after X" rather than "offset 150", because
    // running mail rules can move things out of the inbox!
    const query = DatabaseStore.findAll(Thread, { accountId })
      .where(Thread.attributes.categories.contains(inboxCategoryId))
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .limit(50);

    if (lastTimestamp !== null) {
      query.where(Thread.attributes.lastMessageReceivedTimestamp.lessThan(lastTimestamp));
    }

    query.then(threads => {
      if (!this._reprocessing[accountId]) {
        return;
      }
      if (threads.length === 0) {
        this._onStopReprocessing(accountId);
        return;
      }

      DatabaseStore.findAll(Message, {
        threadId: threads.map(t => t.id),
      }).then(messages => {
        if (!this._reprocessing[accountId]) {
          return;
        }
        const advance = () => {
          if (this._reprocessing[accountId]) {
            this._reprocessing[accountId] = Object.assign({}, this._reprocessing[accountId], {
              count: this._reprocessing[accountId].count + messages.length,
              lastTimestamp: threads.pop().lastMessageReceivedTimestamp,
            });
            this.trigger();
            setTimeout(() => {
              this._reprocessSome(accountId);
            }, 500);
          }
        };
        MailRulesProcessor.processMessages(messages).then(advance, advance);
      });
    });
  };
}

export default new MailRulesStore();

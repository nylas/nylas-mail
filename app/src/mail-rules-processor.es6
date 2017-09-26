import _ from 'underscore';

import Task from './flux/tasks/task';
import Actions from './flux/actions';
import Category from './flux/models/category';
import Thread from './flux/models/thread';
import Label from './flux/models/label';
import CategoryStore from './flux/stores/category-store';
import DatabaseStore from './flux/stores/database-store';
import TaskQueue from './flux/stores/task-queue';

import { ConditionMode, ConditionTemplates } from './mail-rules-templates';

import ChangeUnreadTask from './flux/tasks/change-unread-task';
import ChangeFolderTask from './flux/tasks/change-folder-task';
import ChangeStarredTask from './flux/tasks/change-starred-task';
import ChangeLabelsTask from './flux/tasks/change-labels-task';
let MailRulesStore = null;

/**
Note: At first glance, it seems like these task factory methods should use the
TaskFactory. Unfortunately, the TaskFactory uses the CategoryStore and other
information about the current view. Maybe after the unified inbox refactor...
*/
const MailRulesActions = {
  markAsImportant: async (message, thread) => {
    const important = await DatabaseStore.findBy(Category, {
      name: 'important',
      accountId: thread.accountId,
    });
    if (!important) {
      throw new Error('Could not find `important` label');
    }
    return new ChangeLabelsTask({
      labelsToAdd: [important],
      labelsToRemove: [],
      threads: [thread.id],
      source: 'Mail Rules',
    });
  },

  moveToTrash: async (message, thread) => {
    if (CategoryStore.getInboxCategory(thread.accountId) instanceof Label) {
      return MailRulesActions.moveToLabel(message, thread, 'trash');
    }
    const folder = await DatabaseStore.findBy(Category, {
      name: 'trash',
      accountId: thread.accountId,
    });
    if (!folder) {
      throw new Error('The folder could not be found.');
    }
    return new ChangeFolderTask({
      folder: folder,
      threads: [thread.id],
      source: 'Mail Rules',
    });
  },

  markAsRead: (message, thread) => {
    return new ChangeUnreadTask({
      unread: false,
      threads: [thread.id],
      source: 'Mail Rules',
    });
  },

  star: (message, thread) => {
    return new ChangeStarredTask({
      starred: true,
      threads: [thread.id],
      source: 'Mail Rules',
    });
  },

  changeFolder: async (message, thread, value) => {
    if (!value) {
      throw new Error('A folder is required.');
    }
    const folder = await DatabaseStore.findBy(Category, { id: value, accountId: thread.accountId });
    if (!folder) {
      throw new Error('The folder could not be found.');
    }
    return new ChangeFolderTask({
      folder: folder,
      threads: [thread.id],
      source: 'Mail Rules',
    });
  },

  applyLabel: async (message, thread, value) => {
    if (!value) {
      throw new Error('A label is required.');
    }
    const label = await DatabaseStore.findBy(Category, { id: value, accountId: thread.accountId });
    if (!label) {
      throw new Error('The label could not be found.');
    }
    return new ChangeLabelsTask({
      labelsToAdd: [label],
      labelsToRemove: [],
      threads: [thread.id],
      source: 'Mail Rules',
    });
  },

  // Should really be moveToArchive but stuck with legacy name
  applyLabelArchive: (message, thread) => {
    return MailRulesActions.moveToLabel(message, thread, 'all');
  },

  moveToLabel: async (message, thread, nameOrId) => {
    if (!nameOrId) {
      throw new Error('A label is required.');
    }

    const { withId, withName } = await Promise.props({
      withId: DatabaseStore.findBy(Category, { id: nameOrId, accountId: thread.accountId }),
      withName: DatabaseStore.findBy(Category, { name: nameOrId, accountId: thread.accountId }),
    });
    const label = withId || withName;
    if (!label) {
      throw new Error('The label could not be found.');
    }
    return new ChangeLabelsTask({
      source: 'Mail Rules',
      labelsToRemove: []
        .concat(thread.labels)
        .filter(l => !l.isLockedCategory() && l.id !== label.id),
      labelsToAdd: [label],
      threads: [thread.id],
    });
  },
};

class MailRulesProcessor {
  async processMessages(messages) {
    MailRulesStore = MailRulesStore || require('./flux/stores/mail-rules-store').default; //eslint-disable-line
    if (messages.length === 0) {
      return;
    }

    const enabledRules = MailRulesStore.rules().filter(r => !r.disabled);

    // When messages arrive, we process all the messages in parallel, but one
    // rule at a time. This is important, because users can order rules which
    // may do and undo a change. Ie: "Star if from Ben, Unstar if subject is "Bla"
    for (const rule of enabledRules) {
      let matching = messages.filter(message => this._checkRuleForMessage(rule, message));

      // Rules are declared at the message level, but actions are applied to
      // threads. To ensure we don't apply the same action 50x on the same thread,
      // just process one match per thread.
      matching = _.uniq(matching, false, message => message.threadId);
      for (const message of matching) {
        // We always pull the thread from the database, even though it may be in
        // `incoming.thread`, because rules may be modifying it as they run!
        const thread = await DatabaseStore.find(Thread, message.threadId);
        if (!thread) {
          console.warn(`Cannot find thread ${message.threadId} to process mail rules.`);
          continue;
        }
        await this._applyRuleToMessage(rule, message, thread);
      }
    }
  }

  _checkRuleForMessage(rule, message) {
    const fn =
      rule.conditionMode === ConditionMode.All ? Array.prototype.every : Array.prototype.some;
    if (message.accountId !== rule.accountId) {
      return false;
    }

    return fn.call(rule.conditions, condition => {
      const template = ConditionTemplates.find(t => t.key === condition.templateKey);
      const value = template.valueForMessage(message);
      return template.evaluate(condition, value);
    });
  }

  async _applyRuleToMessage(rule, message, thread) {
    try {
      const actionPromises = rule.actions.map(action => {
        const actionFn = MailRulesActions[action.templateKey];
        if (!actionFn) {
          throw new Error(`${action.templateKey} is not a supported action.`);
        }
        return actionFn(message, thread, action.value);
      });

      const actionResults = await Promise.all(actionPromises);
      const actionTasks = actionResults.filter(r => r instanceof Task);
      const performLocalPromises = actionTasks.map(t => TaskQueue.waitForPerformLocal(t));
      Actions.queueTasks(actionTasks);
      await performLocalPromises;
    } catch (err) {
      // Errors can occur if a mail rule specifies an invalid label or folder, etc.
      // Disable the rule. Disable the mail rule so the failure is reflected in the
      // interface.
      Actions.disableMailRule(rule.id, err.toString());
    }
  }
}

export default new MailRulesProcessor();

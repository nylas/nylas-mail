import _ from 'underscore';
import NylasStore from 'nylas-store';

import {
  FeatureUsageStore,
  SyncbackMetadataTask,
  Actions,
  AccountStore,
  DatabaseStore,
  Message,
  CategoryStore,
} from 'nylas-exports';

import SnoozeUtils from './snooze-utils'
import {PLUGIN_ID, PLUGIN_NAME} from './snooze-constants';
import SnoozeActions from './snooze-actions';

class SnoozeStore extends NylasStore {

  constructor(pluginId = PLUGIN_ID, pluginName = PLUGIN_NAME) {
    super();

    this.pluginId = pluginId;
    this.pluginName = pluginName;
    this.accountIds = AccountStore.accounts().map(a => a.id)
    this.snoozeCategoriesPromise = SnoozeUtils.getSnoozeCategoriesByAccount(AccountStore.accounts())
  }

  activate() {
    this.unsubscribers = [
      AccountStore.listen(this.onAccountsChanged),
      SnoozeActions.snoozeThreads.listen(this.onSnoozeThreads),
    ];
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }

  recordSnoozeEvent(threads, snoozeDate, label) {
    try {
      const timeInSec = Math.round(((new Date(snoozeDate)).valueOf() - Date.now()) / 1000);
      Actions.recordUserEvent("Threads Snoozed", {
        timeInSec: timeInSec,
        timeInLog10Sec: Math.log10(timeInSec),
        label: label,
        numItems: threads.length,
      });
    } catch (e) {
      // Do nothing
    }
  }

  groupUpdatedThreads = (threads, snoozeCategoriesByAccount) => {
    const threadsByAccountId = {}

    threads.forEach((thread) => {
      const accId = thread.accountId
      if (!threadsByAccountId[accId]) {
        threadsByAccountId[accId] = {
          threads: [thread],
          snoozeCategoryId: () => snoozeCategoriesByAccount[accId].id,
          returnCategoryId: () => CategoryStore.getInboxCategory(accId).id,
        }
      } else {
        threadsByAccountId[accId].threads.push(thread);
      }
    });
    return threadsByAccountId;
  };

  onAccountsChanged = () => {
    const nextIds = AccountStore.accounts().map(a => a.id)
    const isSameAccountIds = (
      this.accountIds.length === nextIds.length &&
      this.accountIds.length === _.intersection(this.accountIds, nextIds).length
    )
    if (!isSameAccountIds) {
      this.accountIds = nextIds
      this.snoozeCategoriesPromise = SnoozeUtils.getSnoozeCategoriesByAccount(AccountStore.accounts())
    }
  };

  onSnoozeThreads = async (threads, snoozeDate, label) => {
    const lexicon = {
      displayName: "Snooze",
      usedUpHeader: "All Snoozes used",
      iconUrl: "merani://thread-snooze/assets/ic-snooze-modal@2x.png",
    }

    // wait for the "snoozed categories" to become available
    const snoozeCategories = await this.snoozeCategoriesPromise;

    try {
      // ensure the user is authorized to use this feature
      await FeatureUsageStore.asyncUseFeature('snooze', {lexicon});

      // log to analytics
      this.recordSnoozeEvent(threads, snoozeDate, label);

      const updatedThreads = await SnoozeUtils.moveThreadsToSnooze(threads, snoozeCategories, snoozeDate);
      const updatedThreadsByAccountId = this.groupUpdatedThreads(updatedThreads, snoozeCategories);

      // note we don't wait for this to complete currently
      Object.values(updatedThreadsByAccountId).map(async (update) => {
        const {snoozeCategoryId, returnCategoryId} = update;

        // Get messages for those threads and metadata for those.
        const messages = await DatabaseStore.findAll(Message, {
          threadId: update.threads.map(t => t.id),
        });

        for (const message of messages) {
          Actions.queueTask(new SyncbackMetadataTask({
            model: message,
            accountId: message.accountId,
            pluginId: this.pluginId,
            value: {
              expiration: snoozeDate,
              header: message.headerMessageId,
              stableId: message.id,
              snoozeCategoryId,
              returnCategoryId,
            },
          }));
        }
      });
    } catch (error) {
      if (error instanceof FeatureUsageStore.NoProAccessError) {
        return;
      }
      SnoozeUtils.moveThreadsFromSnooze(threads, snoozeCategories)
      Actions.closePopover();
      NylasEnv.reportError(error);
      NylasEnv.showErrorDialog(`Sorry, we were unable to save your snooze settings. ${error.message}`);
    }
  };
}

export default new SnoozeStore();


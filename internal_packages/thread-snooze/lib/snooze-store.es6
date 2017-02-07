import {remote} from 'electron'
import _ from 'underscore';
import {FeatureUsageStore, Actions, NylasAPIHelpers, AccountStore,
  DatabaseStore, Message, CategoryStore} from 'nylas-exports';
import SnoozeUtils from './snooze-utils'
import {PLUGIN_ID, PLUGIN_NAME} from './snooze-constants';
import SnoozeActions from './snooze-actions';

class SnoozeStore {

  constructor(pluginId = PLUGIN_ID, pluginName = PLUGIN_NAME) {
    this.pluginId = pluginId
    this.pluginName = pluginName
    this.accountIds = _.pluck(AccountStore.accounts(), 'id')
    this.snoozeCategoriesPromise = SnoozeUtils.getSnoozeCategoriesByAccount(AccountStore.accounts())
  }

  activate() {
    this.unsubscribers = [
      AccountStore.listen(this.onAccountsChanged),
      SnoozeActions.snoozeThreads.listen(this.onSnoozeThreads),
    ]
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
    const getSnoozeCategory = (accId) => snoozeCategoriesByAccount[accId]
    const {getInboxCategory} = CategoryStore
    const threadsByAccountId = {}

    threads.forEach((thread) => {
      const accId = thread.accountId
      if (!threadsByAccountId[accId]) {
        threadsByAccountId[accId] = {
          threads: [thread],
          snoozeCategoryId: getSnoozeCategory(accId).serverId,
          returnCategoryId: getInboxCategory(accId).serverId,
        }
      } else {
        threadsByAccountId[accId].threads.push(thread);
      }
    });
    return Promise.resolve(threadsByAccountId);
  };

  onAccountsChanged = () => {
    const nextIds = _.pluck(AccountStore.accounts(), 'id')
    const isSameAccountIds = (
      this.accountIds.length === nextIds.length &&
      this.accountIds.length === _.intersection(this.accountIds, nextIds).length
    )
    if (!isSameAccountIds) {
      this.accountIds = nextIds
      this.snoozeCategoriesPromise = SnoozeUtils.getSnoozeCategoriesByAccount(AccountStore.accounts())
    }
  };

  onSnoozeThreads = (threads, snoozeDate, label) => {
    if (!FeatureUsageStore.isUsable("snooze")) {
      remote.dialog.showMessageBox({
        title: 'Out of snoozes',
        detail: `You have used your monthly quota of Snoozes`,
        buttons: ['OK'],
        type: 'info',
      });
      return Promise.resolve()
    }
    this.recordSnoozeEvent(threads, snoozeDate, label)

    const accounts = AccountStore.accountsForItems(threads)
    const promises = accounts.map((acc) => {
      return NylasAPIHelpers.authPlugin(this.pluginId, this.pluginName, acc)
    })

    return Promise.all(promises)
    .then(() => {
      return SnoozeUtils.moveThreadsToSnooze(threads, this.snoozeCategoriesPromise, snoozeDate)
    })
    .then((updatedThreads) => {
      return this.snoozeCategoriesPromise
      .then(snoozeCategories => this.groupUpdatedThreads(updatedThreads, snoozeCategories))
    })
    .then((updatedThreadsByAccountId) => {
      _.each(updatedThreadsByAccountId, (update) => {
        const {snoozeCategoryId, returnCategoryId} = update;

        // Get messages for those threads and metadata for those.
        DatabaseStore.findAll(Message, {threadId: update.threads.map(t => t.id)}).then((messages) => {
          for (const message of messages) {
            const header = message.messageIdHeader;
            const stableId = message.id;
            Actions.setMetadata(message, this.pluginId,
              {expiration: snoozeDate, header, stableId, snoozeCategoryId, returnCategoryId})
          }
        });
      });
    }).then(() => {
      return FeatureUsageStore.useFeature('snooze')
    })
    .catch((error) => {
      SnoozeUtils.moveThreadsFromSnooze(threads, this.snoozeCategoriesPromise)
      Actions.closePopover();
      NylasEnv.reportError(error);
      NylasEnv.showErrorDialog(`Sorry, we were unable to save your snooze settings. ${error.message}`);
    });
  };

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }
}

export default SnoozeStore;

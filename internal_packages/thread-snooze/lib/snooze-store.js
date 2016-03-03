/** @babel */
import _ from 'underscore';
import {Actions, NylasAPI, AccountStore, CategoryStore} from 'nylas-exports';
import {
  moveThreadsToSnooze,
  moveThreadsFromSnooze,
  getSnoozeCategoriesByAccount,
} from './snooze-utils';
import {PLUGIN_ID, PLUGIN_NAME} from './snooze-constants';
import SnoozeActions from './snooze-actions';


class SnoozeStore {

  constructor(pluginId = PLUGIN_ID, pluginName = PLUGIN_NAME) {
    this.pluginId = pluginId
    this.pluginName = pluginName
    this.snoozeCategoriesPromise = getSnoozeCategoriesByAccount()
  }

  activate() {
    this.unsubscribe = SnoozeActions.snoozeThreads.listen(this.onSnoozeThreads)
  }

  recordSnoozeEvent(threads, snoozeDate, label) {
    try {
      const min = Math.round(((new Date(snoozeDate)).valueOf() - Date.now()) / 1000 / 60);
      Actions.recordUserEvent("Snooze Threads", {
        numThreads: threads.length,
        snoozeTime: min,
        buttonType: label,
      });
    } catch (e) {
      // Do nothing
    }
  }

  groupUpdatedThreads = (threads, snoozeCategoriesByAccount) => {
    const getSnoozeCategory = (accId)=> snoozeCategoriesByAccount[accId]
    const {getInboxCategory} = CategoryStore
    const threadsByAccountId = {}

    threads.forEach((thread)=> {
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

  onSnoozeThreads = (threads, snoozeDate, label) => {
    this.recordSnoozeEvent(threads, label)

    const accounts = AccountStore.accountsForItems(threads)
    const promises = accounts.map((acc)=> {
      return NylasAPI.authPlugin(this.pluginId, this.pluginName, acc)
    })
    return Promise.all(promises)
    .then(()=> {
      return moveThreadsToSnooze(threads, this.snoozeCategoriesPromise, snoozeDate)
    })
    .then((updatedThreads)=> {
      return this.snoozeCategoriesPromise
      .then(snoozeCategories => this.groupUpdatedThreads(updatedThreads, snoozeCategories))
    })
    .then((updatedThreadsByAccountId)=> {
      _.each(updatedThreadsByAccountId, (update)=> {
        const {snoozeCategoryId, returnCategoryId} = update;
        Actions.setMetadata(update.threads, this.pluginId, {snoozeDate, snoozeCategoryId, returnCategoryId})
      })
    })
    .catch((error)=> {
      moveThreadsFromSnooze(threads, this.snoozeCategoriesPromise)
      Actions.closePopover();
      NylasEnv.reportError(error);
      NylasEnv.showErrorDialog(`Sorry, we were unable to save your snooze settings. ${error.message}`);
    });
  };

  deactivate() {
    this.unsubscribe()
  }
}

export default SnoozeStore;

/** @babel */
import _ from 'underscore';
import {Actions, NylasAPI, AccountStore} from 'nylas-exports';
import {moveThreadsToSnooze} from './snooze-category-helpers';
import {PLUGIN_ID, PLUGIN_NAME} from './snooze-constants';
import SnoozeActions from './snooze-actions';


class SnoozeStore {

  constructor(pluginId = PLUGIN_ID) {
    this.pluginId = pluginId

    this.unsubscribe = SnoozeActions.snoozeThreads.listen(this.onSnoozeThreads)
  }

  onSnoozeThreads = (threads, snoozeDate)=> {
    try {
      const sec = Math.round(((new Date(snoozeDate)).valueOf() - Date.now()) / 1000);
      Actions.recordUserEvent("Snooze Threads", {
        numThreads: threads.length,
        snoozeTime: sec,
      });
    } catch (e) {
      // Do nothing
    }

    const accounts = AccountStore.accountsForItems(threads)
    const promises = accounts.map((acc)=> {
      return NylasAPI.authPlugin(this.pluginId, PLUGIN_NAME, acc)
    })
    Promise.all(promises)
    .then(()=> {
      return moveThreadsToSnooze(threads, snoozeDate)
    })
    .then((updatedThreadsByAccountId)=> {
      _.each(updatedThreadsByAccountId, (update)=> {
        const {updatedThreads, snoozeCategoryId, returnCategoryId} = update;
        Actions.setMetadata(updatedThreads, this.pluginId, {snoozeDate, snoozeCategoryId, returnCategoryId})
      })
    })
    .catch((error)=> {
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

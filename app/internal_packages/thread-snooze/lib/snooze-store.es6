import _ from 'underscore';
import NylasStore from 'nylas-store';

import {
  FeatureUsageStore,
  SyncbackMetadataTask,
  Actions,
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
  }

  activate() {
    this.unsubscribers = [
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

  groupUpdatedThreads = (threads) => {
    const threadsByAccountId = {}

    threads.forEach((thread) => {
      const accId = thread.accountId
      if (!threadsByAccountId[accId]) {
        threadsByAccountId[accId] = [thread];
      } else {
        threadsByAccountId[accId].threads.push(thread);
      }
    });
    return threadsByAccountId;
  };

  onSnoozeThreads = async (allThreads, snoozeDate, label) => {
    const lexicon = {
      displayName: "Snooze",
      usedUpHeader: "All Snoozes used",
      iconUrl: "mailspring://thread-snooze/assets/ic-snooze-modal@2x.png",
    }

    try {
      // ensure the user is authorized to use this feature
      await FeatureUsageStore.asyncUseFeature('snooze', {lexicon});

      // log to analytics
      this.recordSnoozeEvent(allThreads, snoozeDate, label);

      const updatedThreads = await SnoozeUtils.moveThreadsToSnooze(allThreads, snoozeDate);
      const updatedThreadsByAccountId = this.groupUpdatedThreads(updatedThreads);

      // note we don't wait for this to complete currently
      Object.values(updatedThreadsByAccountId).map(async (threads) => {
        // Get messages for those threads and metadata for those.
        const messages = await DatabaseStore.findAll(Message, {
          threadId: threads.map(t => t.id),
        });

        for (const message of messages) {
          Actions.queueTask(new SyncbackMetadataTask({
            model: message,
            accountId: message.accountId,
            pluginId: this.pluginId,
            value: {
              expiration: snoozeDate,
            },
          }));
        }
      });
    } catch (error) {
      if (error instanceof FeatureUsageStore.NoProAccessError) {
        return;
      }
      SnoozeUtils.moveThreadsFromSnooze(allThreads);
      Actions.closePopover();
      NylasEnv.reportError(error);
      NylasEnv.showErrorDialog(`Sorry, we were unable to save your snooze settings. ${error.message}`);
    }
  };
}

export default new SnoozeStore();


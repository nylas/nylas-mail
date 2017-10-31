import MailspringStore from 'mailspring-store';

import {
  FeatureUsageStore,
  SyncbackMetadataTask,
  Actions,
  DatabaseStore,
  Thread,
} from 'mailspring-exports';

import { markUnreadOrResurfaceThreads, moveThreads, snoozedUntilMessage } from './snooze-utils';
import { PLUGIN_ID } from './snooze-constants';
import SnoozeActions from './snooze-actions';

class SnoozeStore extends MailspringStore {
  activate() {
    this.unsubscribers = [
      SnoozeActions.snoozeThreads.listen(this._onSnoozeThreads),
      DatabaseStore.listen(change => {
        if (change.type !== 'metadata-expiration' || change.objectClass !== Thread.name) {
          return;
        }
        this._onMetadataExpired(change.objects);
      }),
    ];
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub());
  }

  _recordSnoozeEvent(threads, snoozeDate, label) {
    try {
      const timeInSec = Math.round((new Date(snoozeDate).valueOf() - Date.now()) / 1000);
      Actions.recordUserEvent('Threads Snoozed', {
        timeInSec: timeInSec,
        timeInLog10Sec: Math.log10(timeInSec),
        label: label,
        numItems: threads.length,
      });
    } catch (e) {
      // Do nothing
    }
  }

  _onSnoozeThreads = async (threads, snoozeDate, label) => {
    try {
      // ensure the user is authorized to use this feature
      await FeatureUsageStore.asyncUseFeature('snooze', {
        usedUpHeader: 'All Snoozes Used',
        usagePhrase: 'snooze',
        iconUrl: 'mailspring://thread-snooze/assets/ic-snooze-modal@2x.png',
      });

      // log to analytics
      this._recordSnoozeEvent(threads, snoozeDate, label);

      // move the threads to the snoozed folder
      await moveThreads(threads, {
        snooze: true,
        description: snoozedUntilMessage(snoozeDate),
      });

      // attach metadata to the threads to unsnooze them later
      Actions.queueTasks(
        threads.map(
          model =>
            new SyncbackMetadataTask({
              model,
              pluginId: PLUGIN_ID,
              value: {
                expiration: snoozeDate,
              },
            })
        )
      );
    } catch (error) {
      if (error instanceof FeatureUsageStore.NoProAccessError) {
        return;
      }
      moveThreads(threads, { snooze: false, description: 'Unsnoozed' });
      Actions.closePopover();
      AppEnv.reportError(error);
      AppEnv.showErrorDialog(
        `Sorry, we were unable to save your snooze settings. ${error.message}`
      );
    }
  };

  _onUnsnoozeThreads = threads => {
    // move the threads back to the inbox
    moveThreads(threads, { snooze: false, description: 'Unsnoozed' });

    // mark the threads unread if setting is enabled
    markUnreadOrResurfaceThreads(threads, 'Unsnoozed message');
  };

  _onMetadataExpired = threads => {
    const unsnooze = threads.filter(thread => {
      const metadata = thread.metadataForPluginId(PLUGIN_ID);
      return metadata && metadata.expiration && metadata.expiration < new Date();
    });
    if (unsnooze.length > 0) {
      // remove the expiration on the metadata. note this is super important,
      // otherwise we'll receive a notification from the sync worker over and
      // over again.
      Actions.queueTasks(
        threads.map(
          model =>
            new SyncbackMetadataTask({
              model,
              pluginId: PLUGIN_ID,
              value: {
                expiration: null,
              },
            })
        )
      );

      // unsnooze messages that are still in the snoozed folder. (The user may have
      // moved the thread out of the snoozed folder using another client )
      this._onUnsnoozeThreads(unsnooze.filter(t => t.categories.find(c => c.role === 'snoozed')));
    }
  };
}

export default new SnoozeStore();

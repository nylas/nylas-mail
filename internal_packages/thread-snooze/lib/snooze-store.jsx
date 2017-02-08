import _ from 'underscore';
import {React, FeatureUsageStore, Actions, AccountStore,
  DatabaseStore, Message, CategoryStore} from 'nylas-exports';
import {FeatureUsedUpModal} from 'nylas-component-kit'
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
      const featureData = FeatureUsageStore.featureData("snooze");

      let headerText = "";
      let rechargeText = ""
      if (!featureData.quota) {
        headerText = "Snooze not yet enabled";
        rechargeText = "Upgrade to Pro to start Snoozing"
      } else {
        headerText = "All Snoozes used";
        let time = "later";
        if (featureData.period === "hourly") {
          time = "next hour"
        } else if (featureData.period === "daily") {
          time = "tomorrow"
        } else if (featureData.period === "weekly") {
          time = "next week"
        } else if (featureData.period === "monthly") {
          time = "next month"
        } else if (featureData.period === "yearly") {
          time = "next year"
        } else if (featureData.period === "unlimited") {
          time = "if you upgrade to Pro"
        }
        rechargeText = `You’ll have ${featureData.quota} more snoozes ${time}`
      }

      Actions.openModal({
        component: (
          <FeatureUsedUpModal
            modalClass="snooze"
            featureName="Snooze"
            headerText={headerText}
            iconUrl="nylas://thread-snooze/assets/ic-snooze-modal@2x.png"
            rechargeText={rechargeText}
          />
        ),
        height: 575,
        width: 412,
      })
      return Promise.resolve()
    }
    this.recordSnoozeEvent(threads, snoozeDate, label)

    return FeatureUsageStore.useFeature('snooze')
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

import Rx from 'rx-lite';
import React from 'react';
import NylasStore from 'nylas-store';
import { FeatureUsedUpModal } from 'nylas-component-kit';
import Actions from '../actions';
import IdentityStore from './identity-store';
import SendFeatureUsageEventTask from '../tasks/send-feature-usage-event-task';

class NoProAccessError extends Error {}

/**
 * FeatureUsageStore is backed by the IdentityStore
 *
 * The billing site is responsible for returning with the Identity object
 * a usage hash that includes all supported features, their quotas for the
 * user, and the current usage of that user. We keep a cache locally
 *
 * The final schema looks like (Feb 7, 2017):
 *
 * NylasID = {
 *   ...
 *   "featureUsage": {
 *     "snooze": {
 *       "quota": 15,
 *       "period": "monthly",
 *       "usedInPeriod": 10,
 *       "featureLimitName": "snooze-experiment-A",
 *     },
 *     "send-later": {
 *       "quota": 99999,
 *       "period": "unlimited",
 *       "usedInPeriod": 228,
 *       "featureLimitName": "send-later-unlimited-A",
 *     },
 *     "reminders": {
 *       "quota": 10,
 *       "period": "daily",
 *       "usedInPeriod": 10,
 *       "featureLimitName": null,
 *     },
 *   },
 *   ...
 * }
 *
 * Valid periods are:
 * 'hourly', 'daily', 'weekly', 'monthly', 'yearly', 'unlimited'
 */
class FeatureUsageStore extends NylasStore {
  constructor() {
    super();
    this._waitForModalClose = [];
    this.NoProAccessError = NoProAccessError;

    /**
     * The IdentityStore triggers both after we update it, and when it
     * polls for new data every several minutes or so.
     */
    this._disp = Rx.Observable.fromStore(IdentityStore).subscribe(() => {
      this.trigger();
    });
    this._usub = Actions.closeModal.listen(this._onModalClose);
  }

  deactivate() {
    this._disp.dispose();
    this._usub();
  }

  displayUpgradeModal(feature, { lexicon }) {
    const { headerText, rechargeText } = this._modalText(feature, lexicon);

    Actions.openModal({
      height: 575,
      width: 412,
      component: (
        <FeatureUsedUpModal
          modalClass={feature}
          headerText={headerText}
          iconUrl={lexicon.iconUrl}
          rechargeText={rechargeText}
        />
      ),
    });
  }

  async asyncUseFeature(feature, lexicon = {}) {
    if (this._isUsable(feature)) {
      this._markFeatureUsed(feature);
      return true;
    }

    this.displayUpgradeModal(feature, { lexicon });

    return new Promise((resolve, reject) => {
      this._waitForModalClose.push({ resolve, reject, feature });
    });
  }

  _onModalClose = async () => {
    for (const { feature, resolve, reject } of this._waitForModalClose) {
      if (this._isUsable(feature)) {
        this._markFeatureUsed(feature);
        resolve();
      } else {
        reject(new NoProAccessError(feature));
      }
    }
    this._waitForModalClose = [];
  };

  _modalText(feature, lexicon = {}) {
    const featureData = this._dataForFeature(feature);

    let headerText = '';
    let rechargeText = '';
    if (!featureData.quota) {
      headerText = `Uhoh - that's a pro feature!`;
      rechargeText = `Upgrade to Mailspring Pro to ${lexicon.usagePhrase}.`;
    } else {
      headerText = lexicon.usedUpHeader || "You've reached your quota";
      let time = 'later';
      if (featureData.period === 'hourly') {
        time = 'an hour';
      } else if (featureData.period === 'daily') {
        time = 'a day';
      } else if (featureData.period === 'weekly') {
        time = 'a week';
      } else if (featureData.period === 'monthly') {
        time = 'a month';
      } else if (featureData.period === 'yearly') {
        time = 'a year';
      }
      rechargeText = `You can ${lexicon.usagePhrase} ${featureData.quota} emails ${time} with Mailspring Basic. Upgrade to Pro today!`;
    }
    return { headerText, rechargeText };
  }

  _dataForFeature(feature) {
    const usage = IdentityStore.identity().featureUsage || {};
    if (!usage[feature]) {
      AppEnv.reportError(new Error(`Warning: No usage information available for ${feature}`));
      return {};
    }
    return usage[feature];
  }

  _isUsable(feature) {
    const { usedInPeriod, quota } = this._dataForFeature(feature);
    if (!quota) {
      return true;
    }
    return usedInPeriod < quota;
  }

  _markFeatureUsed(feature) {
    const next = JSON.parse(JSON.stringify(IdentityStore.identity()));
    if (next.featureUsage[feature]) {
      next.featureUsage[feature].usedInPeriod += 1;
      IdentityStore.saveIdentity(next);
    }
    Actions.queueTask(new SendFeatureUsageEventTask({ feature }));
  }
}

export default new FeatureUsageStore();

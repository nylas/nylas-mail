import Rx from 'rx-lite'
import React from 'react'
import NylasStore from 'nylas-store'
import {FeatureUsedUpModal} from 'nylas-component-kit'
import Actions from '../actions'
import IdentityStore from './identity-store'
import TaskQueueStatusStore from './task-queue-status-store'
import SendFeatureUsageEventTask from '../tasks/send-feature-usage-event-task'

class NoProAccess extends Error { }

/**
 * FeatureUsageStore is backed by the IdentityStore
 *
 * The billing site is responsible for returning with the Identity object
 * a usage hash that includes all supported features, their quotas for the
 * user, and the current usage of that user. We keep a cache locally
 *
 * The Identity object (aka Nylas ID or N1User) has a field called
 * `feature_usage`. The schema for `feature_usage` is computed dynamically
 * in `compute_feature_usage` here:
 * https://github.com/nylas/cloud-core/blob/master/redwood/models/n1.py#L175-207
 *
 * The schema of each feature is determined by the `FeatureUsage` model in
 * redwood here:
 * https://github.com/nylas/cloud-core/blob/master/redwood/models/feature_usage.py#L14-32
 *
 * The final schema looks like (Feb 7, 2017):
 *
 * NylasID = {
 *   ...
 *   "feature_usage": {
 *     "snooze": {
 *       "quota": 15,
 *       "period": "monthly",
 *       "used_in_period": 10,
 *       "feature_limit_name": "snooze-experiment-A",
 *     },
 *     "send-later": {
 *       "quota": 99999,
 *       "period": "unlimited",
 *       "used_in_period": 228,
 *       "feature_limit_name": "send-later-unlimited-A",
 *     },
 *     "reminders": {
 *       "quota": 10,
 *       "period": "daily",
 *       "used_in_period": 10,
 *       "feature_limit_name": null,
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
    super()
    this._waitForModalClose = []
    this.NoProAccess = NoProAccess
  }

  activate() {
    /**
     * The IdentityStore triggers both after we update it, and when it
     * polls for new data every several minutes or so.
     */
    this._disp = Rx.Observable.fromStore(IdentityStore).subscribe(() => {
      this.trigger()
    })
    this._usub = Actions.closeModal.listen(this._onModalClose)
  }

  deactivate() {
    this._disp.dispose();
    this._usub()
  }

  async asyncUseFeature(feature, {lexicon = {}} = {}) {
    if (IdentityStore.hasProAccess() || this._isUsable(feature)) {
      return this._markFeatureUsed(feature)
    }

    const {headerText, rechargeText} = this._modalText(feature, lexicon)
    Actions.openModal({
      component: (
        <FeatureUsedUpModal
          modalClass={feature}
          featureName={lexicon.displayName}
          headerText={headerText}
          iconUrl={lexicon.iconUrl}
          rechargeText={rechargeText}
        />
      ),
      height: 575,
      width: 412,
    })
    return new Promise((resolve, reject) => {
      this._waitForModalClose.push({resolve, reject, feature})
    })
  }

  _onModalClose = async () => {
    for (const {feature, resolve, reject} of this._waitForModalClose) {
      if (IdentityStore.hasProAccess() || this._isUsable(feature)) {
        await this._markFeatureUsed(feature)
        resolve()
      } else {
        reject(new NoProAccess(feature))
      }
    }
    this._waitForModalClose = []
  }

  _modalText(feature, lexicon = {}) {
    const featureData = this._featureData(feature);

    let headerText = "";
    let rechargeText = ""
    if (!featureData.quota) {
      headerText = `${lexicon.displayName} not yet enabled`;
      rechargeText = `Upgrade to Pro to use ${lexicon.displayName}`
    } else {
      headerText = lexicon.usedUpHeader || "You've reached your quota";
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
      rechargeText = `You’ll have ${featureData.quota} more ${time}`
    }
    return {headerText, rechargeText}
  }

  _featureData(feature) {
    const usage = this._featureUsage()
    if (!usage[feature]) {
      NylasEnv.reportError(new Error(`${feature} isn't supported`));
      return {}
    }
    return usage[feature]
  }

  _isUsable(feature) {
    const usage = this._featureUsage()
    if (!usage[feature]) {
      NylasEnv.reportError(new Error(`${feature} isn't supported`));
      return false
    }
    return usage[feature].used_in_period < usage[feature].quota
  }

  async _markFeatureUsed(featureName) {
    const task = new SendFeatureUsageEventTask(featureName)
    Actions.queueTask(task);
    await TaskQueueStatusStore.waitForPerformLocal(task)
    const feat = IdentityStore.identity().feature_usage[featureName]
    return feat.quota - feat.used_in_period
  }

  _featureUsage() {
    return Object.assign({}, IdentityStore.identity().feature_usage) || {}
  }
}

export default new FeatureUsageStore()

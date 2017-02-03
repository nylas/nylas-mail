import Rx from 'rx-lite'
import NylasStore from 'nylas-store'
import Actions from '../actions'
import IdentityStore from './identity-store'
import TaskQueueStatusStore from './task-queue-status-store'
import SendFeatureUsageEventTask from '../tasks/send-feature-usage-event-task'

/**
 * FeatureUsageStore is backed by the IdentityStore
 *
 * The billing site is responsible for returning with the Identity object
 * a usage hash that includes all supported features, their quotas for the
 * user, and the current usage of that user. We keep a cache locally
 */
class FeatureUsageStore extends NylasStore {
  activate() {
    /**
     * The IdentityStore triggers both after we update it, and when it
     * polls for new data every several minutes or so.
     */
    this._sub = Rx.Observable.fromStore(IdentityStore).subscribe(() => {
      this.trigger()
    })
  }

  isUsable(feature) {
    const usage = this._featureUsage()
    if (!usage[feature]) {
      NylasEnv.reportError(`${feature} isn't supported`);
      return false
    }
    return usage[feature].used_in_period < usage[feature].quota
  }

  async useFeature(featureName) {
    if (!this.isUsable(featureName)) {
      throw new Error(`${featureName} is not usable! Check "FeatureUsageStore.isUsable" first`);
    }
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

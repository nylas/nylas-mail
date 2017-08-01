import Task from './task';
import {makeRequest, PermanentErrorCodes} from '../nylas-api-request'
import {APIError} from '../errors'
import IdentityStore from '../stores/identity-store'

export default class SendFeatureUsageEventTask extends Task {
  constructor(featureName) {
    super();
    this.featureName = featureName
  }

  async performLocal(increment = 1) {
    const newIdent = IdentityStore.identity();
    if (!newIdent.feature_usage[this.featureName]) {
      throw new Error(`Can't use ${this.featureName}. Does not exist on identity`)
    }
    newIdent.feature_usage[this.featureName].used_in_period += increment
    await IdentityStore.saveIdentity(newIdent)
  }

  revert() {
    this.performLocal(-1)
  }

  async performRemote() {
    try {
      const updatedIdentity = await makeRequest({
        server: 'identity',
        method: 'POST',
        path: `/api/feature_usage_event`,
        body: {
          feature_name: this.featureName,
        },
      });
      await IdentityStore.saveIdentity(updatedIdentity);
      return Task.Status.Success;
    } catch (err) {
      if (err instanceof APIError) {
        if (PermanentErrorCodes.includes(err.statusCode)) {
          this.revert()
          return Promise.resolve([Task.Status.Failed, err])
        }
        return Promise.resolve(Task.Status.Retry)
      }

      this.revert()
      NylasEnv.reportError(err);
      return Promise.resolve([Task.Status.Failed, err])
    }
  }
}

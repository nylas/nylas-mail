import {Actions, TaskQueue, TaskQueueStatusStore} from 'nylas-exports'
import FeatureUsageStore from '../../src/flux/stores/feature-usage-store'
import Task from '../../src/flux/tasks/task'
import SendFeatureUsageEventTask from '../../src/flux/tasks/send-feature-usage-event-task'
import IdentityStore from '../../src/flux/stores/identity-store'

describe("FeatureUsageStore", function featureUsageStoreSpec() {
  beforeEach(() => {
    this.oldIdent = IdentityStore._identity;
    IdentityStore._identity = {id: 'foo'}
    IdentityStore._identity.feature_usage = {
      "is-usable": {
        quota: 10,
        peroid: 'monthly',
        used_in_period: 8,
        feature_limit_name: 'Usable Group A',
      },
      "not-usable": {
        quota: 10,
        peroid: 'monthly',
        used_in_period: 10,
        feature_limit_name: 'Unusable Group A',
      },
    }
  });

  afterEach(() => {
    IdentityStore._identity = this.oldIdent
  });

  describe("isUsable", () => {
    it("returns true if a feature hasn't met it's quota", () => {
      expect(FeatureUsageStore.isUsable("is-usable")).toBe(true)
    });

    it("returns false if a feature is at its quota", () => {
      expect(FeatureUsageStore.isUsable("not-usable")).toBe(false)
    });

    it("warns if asking for an unsupported feature", () => {
      spyOn(NylasEnv, "reportError")
      expect(FeatureUsageStore.isUsable("unsupported")).toBe(false)
      expect(NylasEnv.reportError).toHaveBeenCalled()
    });
  });

  describe("useFeature", () => {
    beforeEach(() => {
      spyOn(SendFeatureUsageEventTask.prototype, "performRemote").andReturn(Promise.resolve(Task.Status.Success));
      spyOn(IdentityStore, "saveIdentity").andCallFake((ident) => {
        IdentityStore._identity = ident
      })
      spyOn(TaskQueueStatusStore, "waitForPerformLocal").andReturn(Promise.resolve())
      spyOn(Actions, 'queueTask').andCallFake((task) => {
        task.performLocal()
      })
    });

    afterEach(() => {
      TaskQueue._queue = []
    })

    it("returns the num remaining if successful", async () => {
      let numLeft = await FeatureUsageStore.useFeature('is-usable');
      expect(numLeft).toBe(1)
      numLeft = await FeatureUsageStore.useFeature('is-usable');
      expect(numLeft).toBe(0)
    });

    it("throws if it was over quota", async () => {
      try {
        await FeatureUsageStore.useFeature("not-usable");
        throw new Error("This should throw")
      } catch (err) {
        expect(err.message).toMatch(/not usable/)
      }
    });

    it("throws if using an unsupported feature", async () => {
      spyOn(NylasEnv, "reportError")
      try {
        await FeatureUsageStore.useFeature("unsupported");
        throw new Error("This should throw")
      } catch (err) {
        expect(err.message).toMatch(/supported/)
      }
    });
  });
});

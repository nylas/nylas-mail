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
        period: 'monthly',
        used_in_period: 8,
        feature_limit_name: 'Usable Group A',
      },
      "not-usable": {
        quota: 10,
        period: 'monthly',
        used_in_period: 10,
        feature_limit_name: 'Unusable Group A',
      },
    }
  });

  afterEach(() => {
    IdentityStore._identity = this.oldIdent
  });

  describe("_isUsable", () => {
    it("returns true if a feature hasn't met it's quota", () => {
      expect(FeatureUsageStore._isUsable("is-usable")).toBe(true)
    });

    it("returns false if a feature is at its quota", () => {
      expect(FeatureUsageStore._isUsable("not-usable")).toBe(false)
    });

    it("warns if asking for an unsupported feature", () => {
      spyOn(NylasEnv, "reportError")
      expect(FeatureUsageStore._isUsable("unsupported")).toBe(false)
      expect(NylasEnv.reportError).toHaveBeenCalled()
    });
  });

  describe("_markFeatureUsed", () => {
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
      let numLeft = await FeatureUsageStore._markFeatureUsed('is-usable');
      expect(numLeft).toBe(1)
      numLeft = await FeatureUsageStore._markFeatureUsed('is-usable');
      expect(numLeft).toBe(0)
    });
  });

  describe("use feature", () => {
    beforeEach(() => {
      spyOn(FeatureUsageStore, "_markFeatureUsed").andReturn(Promise.resolve());
      spyOn(Actions, "openModal")
    });

    it("marks the feature used if you have pro access", async () => {
      spyOn(IdentityStore, "hasProAccess").andReturn(true);
      await FeatureUsageStore.asyncUseFeature('not-usable')
      expect(FeatureUsageStore._markFeatureUsed).toHaveBeenCalled();
      expect(FeatureUsageStore._markFeatureUsed.callCount).toBe(1);
    });

    it("marks the feature used if it's usable", async () => {
      spyOn(IdentityStore, "hasProAccess").andReturn(false);
      await FeatureUsageStore.asyncUseFeature('is-usable')
      expect(FeatureUsageStore._markFeatureUsed).toHaveBeenCalled();
      expect(FeatureUsageStore._markFeatureUsed.callCount).toBe(1);
    });

    describe("showing modal", () => {
      beforeEach(() => {
        this.hasProAccess = false;
        spyOn(IdentityStore, "hasProAccess").andCallFake(() => {
          return this.hasProAccess;
        })
        this.lexicon = {
          displayName: "Test Name",
          rechargeCTA: "recharge me",
          usedUpHeader: "all test used",
          iconUrl: "icon url",
        }
      });

      it("resolves the modal if you upgrade", async () => {
        setImmediate(() => {
          this.hasProAccess = true;
          FeatureUsageStore._onModalClose()
        })
        await FeatureUsageStore.asyncUseFeature('not-usable', {lexicon: this.lexicon});
        expect(Actions.openModal).toHaveBeenCalled();
        expect(Actions.openModal.calls.length).toBe(1)
      });

      it("pops open a modal with the correct text", async () => {
        setImmediate(() => {
          this.hasProAccess = true;
          FeatureUsageStore._onModalClose()
        })
        await FeatureUsageStore.asyncUseFeature('not-usable', {lexicon: this.lexicon});
        expect(Actions.openModal).toHaveBeenCalled();
        expect(Actions.openModal.calls.length).toBe(1)
        const component = Actions.openModal.calls[0].args[0].component;
        expect(component.props).toEqual({
          modalClass: "not-usable",
          featureName: "Test Name",
          headerText: "all test used",
          iconUrl: "icon url",
          rechargeText: "You’ll have 10 more next month",
        })
      });

      it("rejects if you don't upgrade", async () => {
        let caughtError = false;
        setImmediate(() => {
          this.hasProAccess = false;
          FeatureUsageStore._onModalClose()
        })
        try {
          await FeatureUsageStore.asyncUseFeature('not-usable', {lexicon: this.lexicon});
        } catch (err) {
          expect(err instanceof FeatureUsageStore.NoProAccess).toBe(true)
          caughtError = true;
        }
        expect(caughtError).toBe(true)
      });
    });
  });
});

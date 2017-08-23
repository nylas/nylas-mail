import {Actions, TaskQueue} from 'nylas-exports'
import FeatureUsageStore from '../../src/flux/stores/feature-usage-store'
import IdentityStore from '../../src/flux/stores/identity-store'

describe("FeatureUsageStore", function featureUsageStoreSpec() {
  beforeEach(() => {
    this.oldIdent = IdentityStore._identity;
    IdentityStore._identity = {id: 'foo'}
    IdentityStore._identity.featureUsage = {
      "is-usable": {
        quota: 10,
        period: 'monthly',
        usedInPeriod: 8,
        featureLimitName: 'Usable Group A',
      },
      "not-usable": {
        quota: 10,
        period: 'monthly',
        usedInPeriod: 10,
        featureLimitName: 'Unusable Group A',
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
      spyOn(Actions, 'queueTask');
      spyOn(IdentityStore, "saveIdentity").andCallFake((ident) => {
        IdentityStore._identity = ident
      })
    });

    afterEach(() => {
      TaskQueue._queue = [];
    })

    it("immediately increments the identity counter", () => {
      const before = IdentityStore._identity.featureUsage['is-usable'].usedInPeriod;
      FeatureUsageStore._markFeatureUsed('is-usable');
      const after = IdentityStore._identity.featureUsage['is-usable'].usedInPeriod;
      expect(after).toEqual(before + 1);
    })

    it("queues a task to sync the optimistic changes to the server", () => {
      FeatureUsageStore._markFeatureUsed('is-usable');
      expect(Actions.queueTask).toHaveBeenCalled();
    });
  });

  describe("use feature", () => {
    beforeEach(() => {
      spyOn(FeatureUsageStore, "_markFeatureUsed").andReturn(Promise.resolve());
      spyOn(Actions, "openModal")
    });

    it("marks the feature used if it's usable", async () => {
      await FeatureUsageStore.asyncUseFeature('is-usable')
      expect(FeatureUsageStore._markFeatureUsed).toHaveBeenCalled();
      expect(FeatureUsageStore._markFeatureUsed.callCount).toBe(1);
    });

    describe("showing modal", () => {
      beforeEach(() => {
        this.lexicon = {
          displayName: "Test Name",
          rechargeCTA: "recharge me",
          usedUpHeader: "all test used",
          iconUrl: "icon url",
        }
      });

      it("resolves the modal if you upgrade", async () => {
        setImmediate(() => {
          FeatureUsageStore._onModalClose()
        })
        await FeatureUsageStore.asyncUseFeature('not-usable', {lexicon: this.lexicon});
        expect(Actions.openModal).toHaveBeenCalled();
        expect(Actions.openModal.calls.length).toBe(1)
      });

      it("pops open a modal with the correct text", async () => {
        setImmediate(() => {
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
          FeatureUsageStore._onModalClose()
        })
        try {
          await FeatureUsageStore.asyncUseFeature('not-usable', {lexicon: this.lexicon});
        } catch (err) {
          expect(err instanceof FeatureUsageStore.NoProAccessError).toBe(true)
          caughtError = true;
        }
        expect(caughtError).toBe(true)
      });
    });
  });
});

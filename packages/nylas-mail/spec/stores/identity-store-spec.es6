import {ipcRenderer} from 'electron';
import {Utils, KeyManager, DatabaseTransaction, SendFeatureUsageEventTask} from 'nylas-exports'
import IdentityStore from '../../src/flux/stores/identity-store'

const TEST_NYLAS_ID = "icihsnqh4pwujyqihlrj70vh"
const TEST_TOKEN = "test-token"

describe("IdentityStore", function identityStoreSpec() {
  beforeEach(() => {
    this.identityJSON = {
      valid_until: 1500093224,
      firstname: "Nylas 050",
      lastname: "Test",
      free_until: 1500006814,
      email: "nylas050test@evanmorikawa.com",
      id: TEST_NYLAS_ID,
      seen_welcome_page: true,
      feature_usage: {
        feat: {
          quota: 10,
          used_in_period: 1,
        },
      },
      token: "secret token",
    }
  });

  describe("testing saveIdentity", () => {
    beforeEach(() => {
      IdentityStore._identity = this.identityJSON;
      spyOn(KeyManager, "deletePassword")
      spyOn(KeyManager, "replacePassword")
      spyOn(DatabaseTransaction.prototype, "persistJSONBlob").andReturn(Promise.resolve())
      spyOn(ipcRenderer, "send")
      spyOn(IdentityStore, "trigger")
    });

    it("logs out of nylas identity properly", async () => {
      spyOn(NylasEnv.config, 'unset')
      const promise = IdentityStore._onLogoutNylasIdentity()
      IdentityStore._onIdentityChanged(null)
      return promise.then(() => {
        expect(KeyManager.deletePassword).toHaveBeenCalled()
        expect(KeyManager.replacePassword).not.toHaveBeenCalled()
        expect(ipcRenderer.send).toHaveBeenCalled()
        expect(ipcRenderer.send.calls[0].args[1]).toBe("onIdentityChanged")
        expect(DatabaseTransaction.prototype.persistJSONBlob).toHaveBeenCalled()
        const ident = DatabaseTransaction.prototype.persistJSONBlob.calls[0].args[1]
        expect(ident).toBe(null)
        expect(IdentityStore.trigger).toHaveBeenCalled()
      })
    });

    it("makes the Identity synchronously available for fetching right after saving the identity", async () => {
      const used = () => {
        return IdentityStore.identity().feature_usage.feat.used_in_period
      }
      expect(used()).toBe(1)
      const t = new SendFeatureUsageEventTask('feat');
      await t.performLocal()
      expect(used()).toBe(2)
      expect(ipcRenderer.send).not.toHaveBeenCalled()
      expect(IdentityStore.trigger).toHaveBeenCalled()
    });
  });


  it("can log a feature usage event", async () => {
    spyOn(IdentityStore, "saveIdentity").andReturn(Promise.resolve());
    spyOn(IdentityStore, "nylasIDRequest");
    IdentityStore._identity = this.identityJSON
    IdentityStore._identity.token = TEST_TOKEN;
    IdentityStore._onEnvChanged()
    const t = new SendFeatureUsageEventTask("snooze");
    await t.performRemote()
    const opts = IdentityStore.nylasIDRequest.calls[0].args[0]
    expect(opts).toEqual({
      method: "POST",
      url: "https://billing.nylas.com/n1/user/feature_usage_event",
      body: {
        feature_name: 'snooze',
      },
    })
  });

  describe("returning the identity object", () => {
    beforeEach(() => {
      spyOn(IdentityStore, "saveIdentity").andReturn(Promise.resolve());
    });
    it("returns the identity as null if it looks blank", () => {
      IdentityStore._identity = null;
      expect(IdentityStore.identity()).toBe(null);
      IdentityStore._identity = {};
      expect(IdentityStore.identity()).toBe(null);
      IdentityStore._identity = {token: 'bad'};
      expect(IdentityStore.identity()).toBe(null);
    });

    it("returns a proper clone of the identity", () => {
      IdentityStore._identity = {id: 'bar', deep: {obj: 'baz'}};
      const ident = IdentityStore.identity();
      IdentityStore._identity.deep.obj = 'changed';
      expect(ident.deep.obj).toBe('baz');
    });
  });

  describe("_fetchIdentity", () => {
    beforeEach(() => {
      IdentityStore._identity = this.identityJSON;
      spyOn(IdentityStore, "saveIdentity")
      spyOn(NylasEnv, "reportError")
      spyOn(console, "error")
    });

    it("saves the identity returned", async () => {
      const resp = Utils.deepClone(this.identityJSON);
      resp.feature_usage.feat.quota = 5
      spyOn(IdentityStore, "nylasIDRequest").andCallFake(() => {
        return Promise.resolve(resp)
      })
      await IdentityStore._fetchIdentity();
      expect(IdentityStore.nylasIDRequest).toHaveBeenCalled();
      const options = IdentityStore.nylasIDRequest.calls[0].args[0]
      expect(options.url).toMatch(/\/n1\/user/)
      expect(IdentityStore.saveIdentity).toHaveBeenCalled()
      const newIdent = IdentityStore.saveIdentity.calls[0].args[0]
      expect(newIdent.feature_usage.feat.quota).toBe(5)
      expect(NylasEnv.reportError).not.toHaveBeenCalled()
    });

    it("errors if the json is invalid", async () => {
      spyOn(IdentityStore, "nylasIDRequest").andCallFake(() => {
        return Promise.resolve({})
      })
      await IdentityStore._fetchIdentity();
      expect(NylasEnv.reportError).toHaveBeenCalled()
      expect(IdentityStore.saveIdentity).not.toHaveBeenCalled()
    });

    it("errors if the json doesn't match the ID", async () => {
      const resp = Utils.deepClone(this.identityJSON);
      resp.id = "THE WRONG ID"
      spyOn(IdentityStore, "nylasIDRequest").andCallFake(() => {
        return Promise.resolve(resp)
      })
      await IdentityStore._fetchIdentity();
      expect(NylasEnv.reportError).toHaveBeenCalled()
      expect(IdentityStore.saveIdentity).not.toHaveBeenCalled()
    });
  });
});

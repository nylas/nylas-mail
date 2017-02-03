import {ipcRenderer} from 'electron';
import {KeyManager, DatabaseTransaction, SendFeatureUsageEventTask} from 'nylas-exports'
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
    }
  });

  it("logs out of nylas identity properly", async () => {
    IdentityStore._identity = this.identityJSON;
    spyOn(NylasEnv.config, 'unset')
    spyOn(KeyManager, "deletePassword")
    spyOn(ipcRenderer, "send")
    spyOn(DatabaseTransaction.prototype, "persistJSONBlob").andReturn(Promise.resolve())

    const promise = IdentityStore._onLogoutNylasIdentity()
    IdentityStore._onIdentityChanged(null)
    return promise.then(() => {
      expect(KeyManager.deletePassword).toHaveBeenCalled()
      expect(ipcRenderer.send).toHaveBeenCalled()
      expect(ipcRenderer.send.calls[0].args[1]).toBe("application:relaunch-to-initial-windows")
      expect(DatabaseTransaction.prototype.persistJSONBlob).toHaveBeenCalled()
      const ident = DatabaseTransaction.prototype.persistJSONBlob.calls[0].args[1]
      expect(ident).toBe(null)
    })
  });

  it("can log a feature usage event", () => {
    spyOn(IdentityStore, "nylasIDRequest");
    spyOn(IdentityStore, "saveIdentity");
    IdentityStore._identity = this.identityJSON
    IdentityStore._identity.token = TEST_TOKEN;
    IdentityStore._onEnvChanged()
    const t = new SendFeatureUsageEventTask("snooze");
    t.performRemote()
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
});

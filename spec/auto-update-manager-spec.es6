import url from 'url';
import AutoUpdateManager from '../src/browser/auto-update-manager';

describe("AutoUpdateManager", function autoUpdateManager() {
  beforeEach(() => {
    this.nylasIdentityId = null;
    this.accounts = [{email_address: 'ben@nylas.com'}, {email_address: 'mark@nylas.com'}];
    this.specMode = true;
    this.config = {
      set: jasmine.createSpy('config.set'),
      get: key => {
        if (key === 'nylas.accounts') {
          return this.accounts;
        }
        if (key === 'nylas.identity.id') {
          return this.nylasIdentityId;
        }
        return null;
      },
      onDidChange: (key, callback) => {
        return callback();
      },
    };
  });

  describe("with attached commit version", () =>
    it("correctly sets the feedURL", () => {
      const m = new AutoUpdateManager("3.222.1-abc", this.config, this.specMode);
      spyOn(m, "setupAutoUpdater");

      const {query} = url.parse(m.feedURL, true);
      expect(query.arch).toBe(process.arch);
      expect(query.platform).toBe(process.platform);
      expect(query.version).toBe("3.222.1-abc");
    })
  );

  describe("with no attached commit", () =>
    it("correctly sets the feedURL", () => {
      const m = new AutoUpdateManager("3.222.1", this.config, this.specMode);
      spyOn(m, "setupAutoUpdater");
      const {query} = url.parse(m.feedURL, true);
      expect(query.arch).toBe(process.arch);
      expect(query.platform).toBe(process.platform);
      expect(query.version).toBe("3.222.1");
    })
  );

  describe("when an update identity is not present", () =>
    it("should use anonymous", () => {
      const m = new AutoUpdateManager("3.222.1", this.config, this.specMode);
      spyOn(m, "setupAutoUpdater");
      const {query} = url.parse(m.feedURL, true);
      expect(query.id).toEqual('anonymous');
    })
  );

  describe("when an update identity is already set", () =>
    it("should send it and not save any changes", () => {
      this.nylasIdentityId = "test-nylas-id";
      const m = new AutoUpdateManager("3.222.1", this.config, this.specMode);
      spyOn(m, "setupAutoUpdater");
      const {query} = url.parse(m.feedURL, true);
      expect(query.id).toEqual(this.nylasIdentityId);
    })
  );

  describe("when an update identity is added", () =>
    it("should update the feed URL", () => {
      const m = new AutoUpdateManager("3.222.1", this.config, this.specMode);
      spyOn(m, "setupAutoUpdater");
      let {query} = url.parse(m.feedURL, true);
      expect(query.id).toEqual('anonymous');
      this.nylasIdentityId = '1';
      m._updateFeedURL();
      ({query} = url.parse(m.feedURL, true));
      expect(query.id).toEqual(this.nylasIdentityId);
    })
  );
});

AutoUpdateManager = require('../src/browser/auto-update-manager').default
url = require 'url'

describe "AutoUpdateManager", ->
  beforeEach ->
    @nylasIdentityId = null
    @specMode = true
    @config =
      set: jasmine.createSpy('config.set')
      get: (key) =>
        if key is 'identity.id'
          return @nylasIdentityId
        if key is 'env'
          return 'production'
      onDidChange: (key, callback) =>
        callback()

  describe "with attached commit version", ->
    it "correctly sets the feedURL", ->
      m = new AutoUpdateManager("3.222.1-abc", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      expect(m.feedURL).toEqual('https://updates.getmailspring.com/check/darwin/x64/3.222.1-abc/anonymous/stable')

  describe "with no attached commit", ->
    it "correctly sets the feedURL", ->
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      expect(m.feedURL).toEqual('https://updates.getmailspring.com/check/darwin/x64/3.222.1/anonymous/stable')

  describe "when an update identity is already set", ->
    it "should send it and not save any changes", ->
      @nylasIdentityId = "test-nylas-id"
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      expect(m.feedURL).toEqual('https://updates.getmailspring.com/check/darwin/x64/3.222.1/test-nylas-id/stable')

  describe "when an update identity is added", ->
    it "should update the feed URL", ->
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      expect(m.feedURL.includes('anonymous')).toEqual(true);
      @nylasIdentityId = 'test-nylas-id'
      m.updateFeedURL()
      expect(m.feedURL.includes(@nylasIdentityId)).toEqual(true);

AutoUpdateManager = require('../src/browser/auto-update-manager').default
url = require 'url'

describe "AutoUpdateManager", ->
  beforeEach ->
    @nylasIdentityId = null
    @specMode = true
    @config =
      set: jasmine.createSpy('config.set')
      get: (key) =>
        if key is 'nylas.accounts'
          return [{email_address: 'ben@nylas.com'},{email_address: 'mark@nylas.com'}]
        if key is 'nylas.identity.id'
          return @nylasIdentityId

  describe "with attached commit version", ->
    it "correctly sets the feedURL", ->
      m = new AutoUpdateManager("3.222.1-abc", @config, @specMode)
      spyOn(m, "setupAutoUpdater")

      {query} = url.parse(m.feedURL, true)
      expect(query.arch).toBe process.arch
      expect(query.platform).toBe process.platform
      expect(query.version).toBe "3.222.1-abc"

  describe "with no attached commit", ->
    it "correctly sets the feedURL", ->
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      {query} = url.parse(m.feedURL, true)
      expect(query.arch).toBe process.arch
      expect(query.platform).toBe process.platform
      expect(query.version).toBe "3.222.1"

  describe "when an update identity is not present", ->
    it "should use anonymous", ->
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      {query} = url.parse(m.feedURL, true)
      expect(query.id).toEqual('anonymous')

  describe "when an update identity is already set", ->
    it "should send it and not save any changes", ->
      @nylasIdentityId = "test-nylas-id"
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      {query} = url.parse(m.feedURL, true)
      expect(query.id).toEqual(@nylasIdentityId)

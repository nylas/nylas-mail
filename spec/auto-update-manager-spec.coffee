AutoUpdateManager = require '../src/browser/auto-update-manager'
url = require 'url'

describe "AutoUpdateManager", ->
  beforeEach ->
    @updateIdentity = null
    @specMode = true
    @config =
      set: jasmine.createSpy('config.set')
      get: (key) =>
        if key is 'nylas.accounts'
          return [{email_address: 'ben@nylas.com'},{email_address: 'mark@nylas.com'}]
        if key is 'updateIdentity'
          return @updateIdentity

  describe "with attached commit version", ->
    it "correctly sets the feedURL", ->
      m = new AutoUpdateManager("3.222.1-abc", @config, @specMode)
      spyOn(m, "setupAutoUpdater")

      {query} = url.parse(m.feedUrl, true)
      expect(query.arch).toBe process.arch
      expect(query.platform).toBe process.platform
      expect(query.version).toBe "3.222.1-abc"

  describe "with no attached commit", ->
    it "correctly sets the feedURL", ->
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      {query} = url.parse(m.feedUrl, true)
      expect(query.arch).toBe process.arch
      expect(query.platform).toBe process.platform
      expect(query.version).toBe "3.222.1"

  describe "when an update identity is not present", ->
    it "should save one to @config and send it", ->
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      {query} = url.parse(m.feedUrl, true)

      expect(query.id).toBeDefined()
      expect(@config.set).toHaveBeenCalledWith('updateIdentity', query.id)

  describe "when an update identity is already set", ->
    it "should send it and not save any changes", ->
      @updateIdentity = "test-identity"
      m = new AutoUpdateManager("3.222.1", @config, @specMode)
      spyOn(m, "setupAutoUpdater")
      {query} = url.parse(m.feedUrl, true)

      expect(query.id).toEqual(@updateIdentity)
      expect(@config.set).not.toHaveBeenCalled()

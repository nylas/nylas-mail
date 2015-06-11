AutoUpdateManager = require '../src/browser/auto-update-manager'

describe "AutoUpdateManager", ->
  c1 = get: ->
  c2 = get: -> "major"
  c3 = get: -> "minor"
  c4 = get: -> "patch"
  c5 = get: -> "commit"
  c6 = get: -> "foo"

  base = "https://edgehill.nylas.com/update-check?version="

  beforeEach ->
    @feedUrl = (version, config) ->
      m = new AutoUpdateManager(version, config)
      spyOn(m, "setupAutoUpdater")
      return m.feedUrl

  describe "with attached commit version", ->
    beforeEach ->
      @v = "3.222.1-abc"

    it "correctly sets the feedURL", ->
      expect(@feedUrl(@v, c1)).toBe "#{base}3.222.1-abc&level=patch"
      expect(@feedUrl(@v, c2)).toBe "#{base}3.222.1-abc&level=major"
      expect(@feedUrl(@v, c3)).toBe "#{base}3.222.1-abc&level=minor"
      expect(@feedUrl(@v, c4)).toBe "#{base}3.222.1-abc&level=patch"
      expect(@feedUrl(@v, c5)).toBe "#{base}3.222.1-abc&level=commit"
      expect(@feedUrl(@v, c6)).toBe "#{base}3.222.1-abc&level=patch"

  describe "with no attached commit", ->
    beforeEach ->
      @v = "3.222.1"

    it "correctly sets the feedURL", ->
      expect(@feedUrl(@v, c1)).toBe "#{base}3.222.1&level=patch"
      expect(@feedUrl(@v, c2)).toBe "#{base}3.222.1&level=major"
      expect(@feedUrl(@v, c3)).toBe "#{base}3.222.1&level=minor"
      expect(@feedUrl(@v, c4)).toBe "#{base}3.222.1&level=patch"
      expect(@feedUrl(@v, c5)).toBe "#{base}3.222.1&level=commit"
      expect(@feedUrl(@v, c6)).toBe "#{base}3.222.1&level=patch"

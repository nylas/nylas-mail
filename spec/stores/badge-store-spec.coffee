Label = require('../../src/flux/models/label').default
BadgeStore = require('../../src/flux/stores/badge-store').default

describe "BadgeStore", ->
  describe "_setBadgeForCount", ->
    it "should set the badge correctly", ->
      spyOn(BadgeStore, '_setBadge')
      BadgeStore._unread = 0
      BadgeStore._setBadgeForCount()
      expect(BadgeStore._setBadge).toHaveBeenCalledWith("")
      BadgeStore._unread = 1
      BadgeStore._setBadgeForCount()
      expect(BadgeStore._setBadge).toHaveBeenCalledWith("1")
      BadgeStore._unread = 100
      BadgeStore._setBadgeForCount()
      expect(BadgeStore._setBadge).toHaveBeenCalledWith("100")
      BadgeStore._unread = 1000
      BadgeStore._setBadgeForCount()
      expect(BadgeStore._setBadge).toHaveBeenCalledWith("999+")

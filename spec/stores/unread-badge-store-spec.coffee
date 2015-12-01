Label = require '../../src/flux/models/label'
UnreadBadgeStore = require '../../src/flux/stores/unread-badge-store'

describe "UnreadBadgeStore", ->
  describe "_setBadgeForCount", ->
    it "should set the badge correctly", ->
      spyOn(UnreadBadgeStore, '_setBadge')
      UnreadBadgeStore._count = 0
      UnreadBadgeStore._setBadgeForCount()
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("")
      UnreadBadgeStore._count = 1
      UnreadBadgeStore._setBadgeForCount()
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("1")
      UnreadBadgeStore._count = 100
      UnreadBadgeStore._setBadgeForCount()
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("100")
      UnreadBadgeStore._count = 1000
      UnreadBadgeStore._setBadgeForCount()
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("999+")

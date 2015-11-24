Label = require '../../src/flux/models/label'
UnreadBadgeStore = require '../../src/flux/stores/unread-badge-store'

describe "UnreadBadgeStore", ->
  describe "_setBadgeForCount", ->
    it "should set the badge correctly", ->
      spyOn(UnreadBadgeStore, '_setBadge')
      UnreadBadgeStore._setBadgeForCount(0)
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("")
      UnreadBadgeStore._setBadgeForCount(1)
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("1")
      UnreadBadgeStore._setBadgeForCount(100)
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("100")
      UnreadBadgeStore._setBadgeForCount(1000)
      expect(UnreadBadgeStore._setBadge).toHaveBeenCalledWith("999+")

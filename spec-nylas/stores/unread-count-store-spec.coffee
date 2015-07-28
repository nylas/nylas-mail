UnreadCountStore = require '../../src/flux/stores/unread-count-store'
NamespaceStore = require '../../src/flux/stores/namespace-store'
DatabaseStore = require '../../src/flux/stores/database-store'
Folder = require '../../src/flux/models/folder'
Label = require '../../src/flux/models/label'
Thread = require '../../src/flux/models/thread'
Category = require '../../src/flux/models/category'

describe "UnreadCountStore", ->
  describe "_fetchCount", ->
    beforeEach ->
      atom.testOrganizationUnit = 'folder'
      spyOn(DatabaseStore, 'findBy').andCallFake =>
        Promise.resolve(new Category({id: 'inbox-category-id'}))
      spyOn(DatabaseStore, 'count').andCallFake =>
        Promise.resolve(100)

    it "should create the correct query when using folders", ->
      atom.testOrganizationUnit = 'folder'
      UnreadCountStore._fetchCount()
      advanceClock()
      expect(DatabaseStore.findBy).toHaveBeenCalledWith(Folder, {name: 'inbox'})

      [Model, Matchers] = DatabaseStore.count.calls[0].args
      expect(Model).toBe(Thread)
      expect(Matchers[0].attr.modelKey).toBe('namespaceId')
      expect(Matchers[1].attr.modelKey).toBe('unread')
      expect(Matchers[1].val).toBe(true)
      expect(Matchers[2].attr.modelKey).toBe('folders')
      expect(Matchers[2].val).toBe('inbox-category-id')

    it "should create the correct query when using labels", ->
      atom.testOrganizationUnit = 'label'
      UnreadCountStore._fetchCount()
      advanceClock()
      expect(DatabaseStore.findBy).toHaveBeenCalledWith(Label, {name: 'inbox'})

      [Model, Matchers] = DatabaseStore.count.calls[0].args
      expect(Matchers[0].attr.modelKey).toBe('namespaceId')
      expect(Matchers[1].attr.modelKey).toBe('unread')
      expect(Matchers[1].val).toBe(true)
      expect(Matchers[2].attr.modelKey).toBe('labels')
      expect(Matchers[2].val).toBe('inbox-category-id')

    it "should not trigger if the unread count is the same", ->
      spyOn(UnreadCountStore, 'trigger')
      UnreadCountStore._count = 100
      UnreadCountStore._fetchCount()
      advanceClock()
      expect(UnreadCountStore.trigger).not.toHaveBeenCalled()

      UnreadCountStore._count = 101
      UnreadCountStore._fetchCount()
      advanceClock()
      expect(UnreadCountStore.trigger).toHaveBeenCalled()

    it "should update the badge count", ->
      UnreadCountStore._count = 101
      spyOn(UnreadCountStore, '_updateBadgeForCount')
      UnreadCountStore._fetchCount()
      advanceClock()
      expect(UnreadCountStore._updateBadgeForCount).toHaveBeenCalled()

  describe "_updateBadgeForCount", ->
    it "should set the badge correctly", ->
      spyOn(UnreadCountStore, '_setBadge')
      spyOn(atom, 'isMainWindow').andCallFake -> true
      UnreadCountStore._updateBadgeForCount(0)
      expect(UnreadCountStore._setBadge).toHaveBeenCalledWith("")
      UnreadCountStore._updateBadgeForCount(1)
      expect(UnreadCountStore._setBadge).toHaveBeenCalledWith("1")
      UnreadCountStore._updateBadgeForCount(100)
      expect(UnreadCountStore._setBadge).toHaveBeenCalledWith("100")
      UnreadCountStore._updateBadgeForCount(1000)
      expect(UnreadCountStore._setBadge).toHaveBeenCalledWith("999+")

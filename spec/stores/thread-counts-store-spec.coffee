_ = require 'underscore'
DatabaseStore = require '../../src/flux/stores/database-store'
ThreadCountsStore = require '../../src/flux/stores/thread-counts-store'
Thread = require '../../src/flux/models/thread'
Folder = require '../../src/flux/models/folder'
Label = require '../../src/flux/models/label'
Matcher = require '../../src/flux/attributes/matcher'

describe "ThreadCountsStore", ->
  describe "unreadCountForCategoryId", ->
    it "returns null if no count exists for the category id", ->
      expect(ThreadCountsStore.unreadCountForCategoryId('nan')).toBe(null)

    it "returns the count plus any unsaved deltas", ->
      ThreadCountsStore._counts =
        'b': 3
        'a': 5
      ThreadCountsStore._deltas =
        'a': -1
      expect(ThreadCountsStore.unreadCountForCategoryId('a')).toBe(4)
      expect(ThreadCountsStore.unreadCountForCategoryId('b')).toBe(3)

  describe "when the mutation observer reports count changes", ->
    it "should merge count deltas into existing count detlas", ->
      ThreadCountsStore._deltas =
        'l1': -1
        'l2': 2
      ThreadCountsStore._onCountsChanged({'l1': -1, 'l2': 1, 'l3': 2})
      expect(ThreadCountsStore._deltas).toEqual({
        'l1': -2,
        'l2': 3,
        'l3': 2
      })

    it "should queue a save of the counts", ->
      spyOn(ThreadCountsStore, '_saveCountsSoon')
      ThreadCountsStore._onCountsChanged({'l1': -1, 'l2': 1, 'l3': 2})
      expect(ThreadCountsStore._saveCountsSoon).toHaveBeenCalled()

  describe "when a folder or label is persisted", ->
    beforeEach ->
      @lExisting = new Label(id: "l1", name: "inbox", displayName: "Inbox")
      ThreadCountsStore._categories = [@lExisting]

      @lCreated = new Label(id: "lNew", displayName: "Hi there!")
      @lUpdated = @lExisting.clone()
      @lUpdated.displayName = "Inbox Edited"

      spyOn(ThreadCountsStore, '_fetchCountsMissing')

    describe "in the work window", ->
      beforeEach ->
        spyOn(NylasEnv, 'isWorkWindow').andReturn(true)

      it "should add or update it in it's local categories cache", ->
        ThreadCountsStore._onDatabaseChanged({objectClass: Label.name, objects: [@lCreated]})
        expect(ThreadCountsStore._categories).toEqual([@lExisting, @lCreated])

        ThreadCountsStore._onDatabaseChanged({objectClass: Label.name, objects: [@lUpdated]})
        expect(ThreadCountsStore._categories).toEqual([@lUpdated, @lCreated])

        ThreadCountsStore._categories = []

        ThreadCountsStore._onDatabaseChanged({objectClass: Label.name, objects: [@lCreated, @lUpdated]})
        expect(ThreadCountsStore._categories).toEqual([@lCreated, @lUpdated])

      it "should run _fetchCountsMissing", ->
        ThreadCountsStore._onDatabaseChanged({objectClass: Label.name, objects: [@lUpdated]})
        expect(ThreadCountsStore._fetchCountsMissing).toHaveBeenCalled()

    describe "in other windows", ->
      beforeEach ->
        spyOn(NylasEnv, 'isWorkWindow').andReturn(false)

      it "should do nothing", ->
        ThreadCountsStore._onDatabaseChanged({objectClass: Label.name, objects: [@lCreated]})
        expect(ThreadCountsStore._categories).toEqual([@lExisting])
        expect(ThreadCountsStore._fetchCountsMissing).not.toHaveBeenCalled()

  describe "when counts are persisted", ->
    it "should update it's _counts cache and trigger", ->
      newCounts = {
        'abc': 1
      }
      spyOn(ThreadCountsStore, 'trigger')
      ThreadCountsStore._onDatabaseChanged({objectClass: 'JSONObject', objects: [{key: 'UnreadCounts', json: newCounts}]})
      expect(ThreadCountsStore._counts).toEqual(newCounts)
      expect(ThreadCountsStore.trigger).toHaveBeenCalled()

  describe "_fetchCountsMissing", ->
    beforeEach ->
      ThreadCountsStore._categories = [
        new Label(id: "l1", name: "inbox", displayName: "Inbox", accountId: 'a1'),
        new Label(id: "l2", name: "archive", displayName: "Archive", accountId: 'a1'),
        new Label(id: "l3", displayName: "Happy Days", accountId: 'a1'),
        new Label(id: "l4", displayName: "Sad Days", accountId: 'a1')
      ]
      ThreadCountsStore._counts =
        l1: 10
        l2: 0

    it "should call _fetchCountForCategory for the first category not already in the counts cache", ->
      spyOn(ThreadCountsStore, '_fetchCountForCategory').andCallFake ->
        new Promise (resolve, reject) ->
      ThreadCountsStore._fetchCountsMissing()

      calls = ThreadCountsStore._fetchCountForCategory.calls
      expect(calls.length).toBe(1)
      expect(calls[0].args[0]).toBe(ThreadCountsStore._categories[2])

    describe "when the count promsie finishes", ->
      beforeEach ->
        @countResolve = null
        @countReject = null
        spyOn(ThreadCountsStore, '_fetchCountForCategory').andCallFake =>
          new Promise (resolve, reject) =>
            @countResolve = resolve
            @countReject = reject

      it "should add it to the count cache", ->
        ThreadCountsStore._fetchCountsMissing()
        advanceClock()
        @countResolve(4)
        advanceClock()
        expect(ThreadCountsStore._counts).toEqual({
          l1: 10
          l2: 0
          l3: 4
        })

      it "should call _fetchCountsMissing again to populate the next missing count", ->
        ThreadCountsStore._fetchCountsMissing()
        spyOn(ThreadCountsStore, '_fetchCountsMissing')
        advanceClock()
        @countResolve(4)
        advanceClock()
        expect(ThreadCountsStore._fetchCountsMissing).toHaveBeenCalled()

      describe "when a count fails", ->
        it "should not immediately try to count any other categories", ->
          ThreadCountsStore._fetchCountsMissing()
          spyOn(ThreadCountsStore, '_fetchCountsMissing')
          spyOn(console, 'error')
          advanceClock()
          @countReject(new Error("Oh man something really bad."))
          advanceClock()
          expect(ThreadCountsStore._fetchCountsMissing).not.toHaveBeenCalled()

  describe "_fetchCountForCategory", ->
    it "should make the appropriate label or folder database query", ->
      spyOn(DatabaseStore, 'count')
      Matcher.muid = 0
      ThreadCountsStore._fetchCountForCategory(new Label(id: 'l1', accountId: 'a1'))
      Matcher.muid = 0
      expect(DatabaseStore.count).toHaveBeenCalledWith(Thread, [
        Thread.attributes.accountId.equal('a1'),
        Thread.attributes.unread.equal(true),
        Thread.attributes.labels.contains('l1')
      ])
      Matcher.muid = 0
      ThreadCountsStore._fetchCountForCategory(new Folder(id: 'l1', accountId: 'a1'))
      Matcher.muid = 0
      expect(DatabaseStore.count).toHaveBeenCalledWith(Thread, [
        Thread.attributes.accountId.equal('a1'),
        Thread.attributes.unread.equal(true),
        Thread.attributes.folders.contains('l1')
      ])

  describe "_saveCounts", ->
    beforeEach ->
      ThreadCountsStore._counts =
        'b': 3
        'a': 5
      ThreadCountsStore._deltas =
        'a': -1
        'c': 2

    it "should merge the deltas into the counts and reset the deltas, ignoring any deltas for which the initial count has not been run", ->
      ThreadCountsStore._saveCounts()
      expect(ThreadCountsStore._counts).toEqual({
        'b': 3
        'a': 4
      })

    it "should persist the new counts to the database", ->
      spyOn(DatabaseStore, 'persistJSONObject')
      ThreadCountsStore._saveCounts()
      expect(DatabaseStore.persistJSONObject).toHaveBeenCalledWith('UnreadCounts', ThreadCountsStore._counts)

describe "CategoryDatabaseMutationObserver", ->
  beforeEach ->
    @label1 = new Label(id: "l1", name: "inbox", displayName: "Inbox")
    @label2 = new Label(id: "l2", name: "archive", displayName: "Archive")
    @label3 = new Label(id: "l3", displayName: "Happy Days")
    @label4 = new Label(id: "l4", displayName: "Sad Days")

    @threadA = new Thread
      id: "A"
      unread: true
      labels: [@label1, @label4]
    @threadB = new Thread
      id: "B"
      unread: true
      labels: [@label3]
    @threadC = new Thread
      id: "C"
      unread: false
      labels: [@label1, @label3]

  describe "given a set of modifying models", ->
    it "should call countsDidChange with the folder / label membership deltas", ->
      queryResolves = []
      query = jasmine.createSpy('query').andCallFake =>
        new Promise (resolve, reject) ->
          queryResolves.push(resolve)

      countsDidChange = jasmine.createSpy('countsDidChange')
      m = new ThreadCountsStore.CategoryDatabaseMutationObserver(countsDidChange)

      beforePromise = m.beforeDatabaseChange(query, [@threadA, @threadB, @threadC], [@threadA.id, @threadB.id, @threadC.id])
      expect(query.callCount).toBe(2)
      expect(query.calls[0].args[0]).toEqual("SELECT `Thread`.id as id, `Thread-Label`.`value` as catId FROM `Thread` INNER JOIN `Thread-Label` ON `Thread`.`id` = `Thread-Label`.`id` WHERE `Thread`.id IN ('A','B','C') AND `Thread`.unread = 1")
      expect(query.calls[1].args[0]).toEqual("SELECT `Thread`.id as id, `Thread-Folder`.`value` as catId FROM `Thread` INNER JOIN `Thread-Folder` ON `Thread`.`id` = `Thread-Folder`.`id` WHERE `Thread`.id IN ('A','B','C') AND `Thread`.unread = 1")
      queryResolves[0]([
        {id: @threadA.id, catId: @label1.id},
        {id: @threadA.id, catId: @label3.id},
        {id: @threadB.id, catId: @label2.id},
        {id: @threadB.id, catId: @label3.id},
      ])
      queryResolves[1]([])

      waitsForPromise =>
        beforePromise.then (result) =>
          expect(result).toEqual({
            categories: {
              l1: -1,
              l3: -2,
              l2: -1
            }
          })
          m.afterDatabaseChange(query, [@threadA, @threadB, @threadC], [@threadA.id, @threadB.id, @threadC.id], result)
          expect(countsDidChange).toHaveBeenCalledWith({
            l3: -1,
            l2: -1,
            l4: 1
          })

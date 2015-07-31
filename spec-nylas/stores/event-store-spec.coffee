_ = require 'underscore'
proxyquire = require 'proxyquire'
Event = require '../../src/flux/models/event'
EventStore = require '../../src/flux/stores/event-store'
DatabaseStore = require '../../src/flux/stores/database-store'
NamespaceStore = require '../../src/flux/stores/namespace-store'

describe "EventStore", ->
  beforeEach ->
    atom.testOrganizationUnit = "folder"
    EventStore._eventCache = {}
    EventStore._namespaceId = null
    EventStore._lastNamespaceId = null
    NamespaceStore._current =
      id: "nsid"

  afterEach ->
    atom.testOrganizationUnit = null

  it "initializes the cache from the DB", ->
    spyOn(DatabaseStore, "findAll").andCallFake -> Promise.resolve([])
    advanceClock(30)
    EventStore.constructor()
    advanceClock(30)
    expect(Object.keys(EventStore._eventCache).length).toBe 0
    expect(DatabaseStore.findAll).toHaveBeenCalled()

  describe "when the Namespace updates from null to valid", ->
    beforeEach ->
      spyOn(EventStore, "_refreshCache")
      NamespaceStore.trigger()

    it "triggers a database fetch", ->
      expect(EventStore._refreshCache.calls.length).toBe 1

  describe "when the Namespace updates but the ID doesn't change", ->
    it "does nothing", ->
      spyOn(EventStore, "_refreshCache")
      EventStore._eventCache = {1: '', 2: '', 3: ''}
      EventStore._namespaceId = "nsid"
      EventStore._lastNamespaceId = "nsid"
      NamespaceStore._current =
        id: "nsid"
      NamespaceStore.trigger()
      expect(EventStore._eventCache).toEqual {1: '', 2: '', 3: ''}
      expect(EventStore._refreshCache).not.toHaveBeenCalled()

  describe "getEvent", ->
    beforeEach ->
      @e1 = new Event(id: 1, title:'Test1', start: '', end: '', location: '', participants: [{"name":"Guy", "email":"tester@nylas.com", "status":"noreply"}])
      @e2 = new Event(id: 2, title:'Test2', start: '', end: '', location: '', participants: [{"name":"Guy", "email":"tester@nylas.com", "status":"noreply"}])
      @e3 = new Event(id: 3, title:'Test3', start: '', end: '', location: '', participants: [{"name":"Guy", "email":"tester@nylas.com", "status":"noreply"}])
      @e4 = new Event(id: 4, title:'Test4', start: '', end: '', location: '', participants: [{"name":"Guy", "email":"tester@nylas.com", "status":"noreply"}])
      EventStore._eventCache = {}
      for e in [@e1, @e2, @e3, @e4]
        EventStore._eventCache[e.id] = e

    it "returns event object based on id", ->
      first = EventStore.getEvent(1)
      expect(first.title).toBe 'Test1'
      second = EventStore.getEvent(2)
      expect(second.title).toBe 'Test2'
      third = EventStore.getEvent(3)
      expect(third.title).toBe 'Test3'
      fourth = EventStore.getEvent(4)
      expect(fourth.title).toBe 'Test4'
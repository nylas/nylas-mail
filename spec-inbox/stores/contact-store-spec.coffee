_ = require 'underscore-plus'
proxyquire = require 'proxyquire'
Contact = require '../../src/flux/models/contact'
ContactStore = require '../../src/flux/stores/contact-store'
DatabaseStore = require '../../src/flux/stores/database-store'
NamespaceStore = require '../../src/flux/stores/namespace-store'

describe "ContactStore", ->
  beforeEach ->
    ContactStore._contactCache = []
    ContactStore._fetchOffset = 0
    ContactStore._namespaceId = null
    ContactStore._lastNamespaceId = null
    NamespaceStore._current =
      id: "nsid"

  it "initializes the cache from the DB", ->
    spyOn(DatabaseStore, "findAll").andCallFake -> Promise.resolve([])
    ContactStore.init()
    expect(ContactStore._contactCache.length).toBe 0
    expect(ContactStore._fetchOffset).toBe 0

  describe "when the Namespace updates from null to valid", ->
    beforeEach ->
      spyOn(ContactStore, "_refreshCache")
      NamespaceStore.trigger()

    it "triggers a database fetch", ->
      expect(ContactStore._refreshCache.calls.length).toBe 1

  describe "when the Namespace updates but the ID doesn't change", ->
    it "does nothing", ->
      spyOn(ContactStore, "_refreshCache")
      ContactStore._contactCache = [1,2,3]
      ContactStore._fetchOffset = 3
      ContactStore._namespaceId = "nsid"
      ContactStore._lastNamespaceId = "nsid"
      NamespaceStore._current =
        id: "nsid"
      NamespaceStore.trigger()
      expect(ContactStore._contactCache).toEqual [1,2,3]
      expect(ContactStore._fetchOffset).toBe 3
      expect(ContactStore._refreshCache).not.toHaveBeenCalled()

  describe "when searching for a contact", ->
    beforeEach ->
      @c1 = new Contact(name: "", email: "1test@nilas.com")
      @c2 = new Contact(name: "First", email: "2test@nilas.com")
      @c3 = new Contact(name: "First Last", email: "3test@nilas.com")
      @c4 = new Contact(name: "Fit", email: "fit@nilas.com")
      @c5 = new Contact(name: "Fins", email: "fins@nilas.com")
      @c6 = new Contact(name: "Fill", email: "fill@nilas.com")
      @c7 = new Contact(name: "Fin", email: "fin@nilas.com")
      ContactStore._contactCache = [@c1,@c2,@c3,@c4,@c5,@c6,@c7]

    it "can find by first name", ->
      results = ContactStore.searchContacts("First")
      expect(results.length).toBe 2
      expect(results[0]).toBe @c2
      expect(results[1]).toBe @c3

    it "can find by last name", ->
      results = ContactStore.searchContacts("Last")
      expect(results.length).toBe 1
      expect(results[0]).toBe @c3

    it "can find by email", ->
      results = ContactStore.searchContacts("1test")
      expect(results.length).toBe 1
      expect(results[0]).toBe @c1

    it "is case insensitive", ->
      results = ContactStore.searchContacts("FIrsT")
      expect(results.length).toBe 2
      expect(results[0]).toBe @c2
      expect(results[1]).toBe @c3

    it "only returns the number requested", ->
      results = ContactStore.searchContacts("FIrsT", limit: 1)
      expect(results.length).toBe 1
      expect(results[0]).toBe @c2

    it "returns no more than 5 by default", ->
      results = ContactStore.searchContacts("fi")
      expect(results.length).toBe 5

    it "can return more than 5 if requested", ->
      results = ContactStore.searchContacts("fi", limit: 6)
      expect(results.length).toBe 6

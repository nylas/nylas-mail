_ = require 'underscore'
proxyquire = require 'proxyquire'
Contact = require '../../src/flux/models/contact'
NylasAPI = require '../../src/flux/nylas-api'
ContactStore = require '../../src/flux/stores/contact-store'
DatabaseStore = require '../../src/flux/stores/database-store'
AccountStore = require '../../src/flux/stores/account-store'

describe "ContactStore", ->
  beforeEach ->
    spyOn(atom, "isMainWindow").andReturn true

    @rankings = [
      ["evanA@nylas.com", 10]
      ["evanB@nylas.com", 1]
      ["evanC@nylas.com", 0.1]
    ]

    spyOn(NylasAPI, "makeRequest").andCallFake (options) =>
      if options.path is "/contacts/rankings"
        return Promise.resolve(@rankings)
      else
        throw new Error("Invalid request path!")

    atom.testOrganizationUnit = "folder"
    ContactStore._contactCache = []
    ContactStore._fetchOffset = 0
    ContactStore._accountId = null

  afterEach ->
    atom.testOrganizationUnit = null

  it "initializes the cache from the DB", ->
    spyOn(DatabaseStore, "findAll").andCallFake -> Promise.resolve([])
    ContactStore.constructor()
    expect(ContactStore._contactCache.length).toBe 0
    expect(ContactStore._fetchOffset).toBe 0

  describe "when the Account updates from null to valid", ->
    beforeEach ->
      spyOn(ContactStore, "_refreshCache")
      AccountStore.trigger()

    it "triggers a database fetch", ->
      expect(ContactStore._refreshCache.calls.length).toBe 1

  describe "ranking contacts", ->
    beforeEach ->
      ContactStore._accountId = TEST_ACCOUNT_ID
      @c1 = new Contact(name: "Evan A", email: "evanA@nylas.com")
      @c2 = new Contact(name: "Evan B", email: "evanB@nylas.com")
      @c3 = new Contact(name: "Evan C", email: "evanC@nylas.com")
      @c4 = new Contact(name: "Ben", email: "ben@nylas.com")
      spyOn(DatabaseStore, "findAll").andCallFake ->
        where: -> Promise.resolve([@c3, @c1, @c2, @c4])

    it "Holds the appropriate rankings on refresh and lowercased the emails", ->
      runs ->
        spyOn(ContactStore._rankingsCache, "trigger")
        ContactStore._rankingsCache.refresh()
      waitsFor ->
        ContactStore._rankingsCache.trigger.calls.length > 0
      runs ->
        rankings = ContactStore._rankingsCache.value()

        expect(rankings).toEqual
          "evana@nylas.com": 10
          "evanb@nylas.com": 1
          "evanc@nylas.com": 0.1

    it "triggers a sort on a contact refresh", ->
      spyOn(ContactStore, "_sortContactsCacheWithRankings")
      waitsForPromise ->
        ContactStore.__refreshCache().then -> # Non debounced version
          expect(ContactStore._sortContactsCacheWithRankings).toHaveBeenCalled()

    it "sorts the contact cache by the rankings", ->
      ContactStore._contactCache = [@c3, @c1, @c2, @c4]
      ContactStore._rankingsCache._value =
        "evana@nylas.com": 10
        "evanb@nylas.com": 1
        "evanc@nylas.com": 0.1
      ContactStore._sortContactsCacheWithRankings()
      expect(ContactStore._contactCache).toEqual [@c1, @c2, @c3, @c4]

  describe "when the Account updates but the ID doesn't change", ->
    it "does nothing", ->
      spyOn(ContactStore, "_refreshCache")
      ContactStore._contactCache = [1,2,3]
      ContactStore._fetchOffset = 3
      ContactStore._accountId = TEST_ACCOUNT_ID
      AccountStore.trigger()
      expect(ContactStore._contactCache).toEqual [1,2,3]
      expect(ContactStore._fetchOffset).toBe 3
      expect(ContactStore._refreshCache).not.toHaveBeenCalled()

  describe "when searching for a contact", ->
    beforeEach ->
      @c1 = new Contact(name: "", email: "1test@nylas.com")
      @c2 = new Contact(name: "First", email: "2test@nylas.com")
      @c3 = new Contact(name: "First Last", email: "3test@nylas.com")
      @c4 = new Contact(name: "Fit", email: "fit@nylas.com")
      @c5 = new Contact(name: "Fins", email: "fins@nylas.com")
      @c6 = new Contact(name: "Fill", email: "fill@nylas.com")
      @c7 = new Contact(name: "Fin", email: "fin@nylas.com")
      ContactStore._contactCache = [@c1,@c2,@c3,@c4,@c5,@c6,@c7]

    it "can find by first name", ->
      results = ContactStore.searchContacts("First", noPromise: true)
      expect(results.length).toBe 2
      expect(results[0]).toBe @c2
      expect(results[1]).toBe @c3

    it "can find by last name", ->
      results = ContactStore.searchContacts("Last", noPromise: true)
      expect(results.length).toBe 1
      expect(results[0]).toBe @c3

    it "can find by email", ->
      results = ContactStore.searchContacts("1test", noPromise: true)
      expect(results.length).toBe 1
      expect(results[0]).toBe @c1

    it "is case insensitive", ->
      results = ContactStore.searchContacts("FIrsT", noPromise: true)
      expect(results.length).toBe 2
      expect(results[0]).toBe @c2
      expect(results[1]).toBe @c3

    it "only returns the number requested", ->
      results = ContactStore.searchContacts("FIrsT", limit: 1, noPromise: true)
      expect(results.length).toBe 1
      expect(results[0]).toBe @c2

    it "returns no more than 5 by default", ->
      results = ContactStore.searchContacts("fi", noPromise: true)
      expect(results.length).toBe 5

    it "can return more than 5 if requested", ->
      results = ContactStore.searchContacts("fi", limit: 6, noPromise: true)
      expect(results.length).toBe 6

  describe 'parseContactsInString', ->
    testCases =
      # Single contact test cases
      "evan@nylas.com": [new Contact(name: "evan@nylas.com", email: "evan@nylas.com")]
      "Evan Morikawa": []
      "Evan Morikawa <evan@nylas.com>": [new Contact(name: "Evan Morikawa", email: "evan@nylas.com")]
      "Evan Morikawa (evan@nylas.com)": [new Contact(name: "Evan Morikawa", email: "evan@nylas.com")]
      "spang (Christine Spang) <noreply+phabricator@nilas.com>": [new Contact(name: "spang (Christine Spang)", email: "noreply+phabricator@nilas.com")]
      "spang 'Christine Spang' <noreply+phabricator@nilas.com>": [new Contact(name: "spang 'Christine Spang'", email: "noreply+phabricator@nilas.com")]
      "spang \"Christine Spang\" <noreply+phabricator@nilas.com>": [new Contact(name: "spang \"Christine Spang\"", email: "noreply+phabricator@nilas.com")]
      "Evan (evan@nylas.com)": [new Contact(name: "Evan", email: "evan@nylas.com")]
      "\"Michael\" (mg@nylas.com)": [new Contact(name: "Michael", email: "mg@nylas.com")]
      "announce-uc.1440659566.kankcagcmaacemjlnoma-security=nylas.com@lists.openwall.com": [new Contact(name: "announce-uc.1440659566.kankcagcmaacemjlnoma-security=nylas.com@lists.openwall.com", email: "announce-uc.1440659566.kankcagcmaacemjlnoma-security=nylas.com@lists.openwall.com")]

      # Multiple contact test cases
      "Evan Morikawa <evan@nylas.com>, Ben <ben@nylas.com>": [
        new Contact(name: "Evan Morikawa", email: "evan@nylas.com")
        new Contact(name: "Ben", email: "ben@nylas.com")
      ]
      "mark@nylas.com\nGleb (gleb@nylas.com)\rEvan Morikawa <evan@nylas.com>, spang (Christine Spang) <noreply+phabricator@nilas.com>": [
        new Contact(name: "", email: "mark@nylas.com")
        new Contact(name: "Gleb", email: "gleb@nylas.com")
        new Contact(name: "Evan Morikawa", email: "evan@nylas.com")
        new Contact(name: "spang (Christine Spang)", email: "noreply+phabricator@nilas.com")
      ]

    _.forEach testCases, (value, key) ->
      it "works for #{key}", ->
        waitsForPromise ->
          ContactStore.parseContactsInString(key).then (contacts) ->
            contacts = contacts.map (c) -> c.toString()
            expectedContacts = value.map (c) -> c.toString()
            expect(contacts).toEqual expectedContacts

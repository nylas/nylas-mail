_ = require 'underscore'
proxyquire = require 'proxyquire'
Contact = require '../../src/flux/models/contact'
NylasAPI = require '../../src/flux/nylas-api'
ContactStore = require '../../src/flux/stores/contact-store'
ContactRankingStore = require '../../src/flux/stores/contact-ranking-store'
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
    ContactRankingStore.reset()

  afterEach ->
    atom.testOrganizationUnit = null

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

    it "triggers a sort on a contact refresh", ->
      spyOn(ContactStore, "_sortContactsCacheWithRankings")
      waitsForPromise ->
        ContactStore.__refreshCache().then -> # Non debounced version
          expect(ContactStore._sortContactsCacheWithRankings).toHaveBeenCalled()

    it "sorts the contact cache by the rankings", ->
      spyOn(ContactRankingStore, 'value').andReturn
        "evana@nylas.com": 10
        "evanb@nylas.com": 1
        "evanc@nylas.com": 0.1
      ContactStore._contactCache = [@c3, @c1, @c2, @c4]
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

  describe 'isValidContact', ->
    it "should return true for a variety of valid contacts", ->
      expect(ContactStore.isValidContact(new Contact(name: 'Ben', email: 'ben@nylas.com'))).toBe(true)
      expect(ContactStore.isValidContact(new Contact(email: 'ben@nylas.com'))).toBe(true)
      expect(ContactStore.isValidContact(new Contact(email: 'ben+123@nylas.com'))).toBe(true)

    it "should return false for non-Contact objects", ->
      expect(ContactStore.isValidContact({name: 'Ben', email: 'ben@nylas.com'})).toBe(false)

    it "should return false if the contact has no email", ->
      expect(ContactStore.isValidContact(new Contact(name: 'Ben'))).toBe(false)

    it "should return false if the contact has an email that is not valid", ->
      expect(ContactStore.isValidContact(new Contact(name: 'Ben', email:'Ben <ben@nylas.com>'))).toBe(false)
      expect(ContactStore.isValidContact(new Contact(name: 'Ben', email:'<ben@nylas.com>'))).toBe(false)
      expect(ContactStore.isValidContact(new Contact(name: 'Ben', email:'"ben@nylas.com"'))).toBe(false)

    it "returns false if we're not passed a contact", ->
      expect(ContactStore.isValidContact()).toBe false

    it "returns false if the contact doesn't have an email", ->
      expect(ContactStore.isValidContact(new Contact(name: "test"))).toBe false

    it "returns false if the email doesn't satisfy the regex", ->
      expect(ContactStore.isValidContact(new Contact(name: "test", email: "foo"))).toBe false

    it "returns false if the email doesn't match", ->
      expect(ContactStore.isValidContact(new Contact(name: "test", email: "foo@"))).toBe false

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

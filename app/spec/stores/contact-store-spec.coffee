_ = require 'underscore'
Rx = require 'rx-lite'
{MailspringTestUtils} = require 'mailspring-exports'
Contact = require('../../src/flux/models/contact').default
ContactStore = require('../../src/flux/stores/contact-store').default
DatabaseStore = require('../../src/flux/stores/database-store').default
AccountStore = require('../../src/flux/stores/account-store').default

{mockObservable} = MailspringTestUtils

xdescribe "ContactStore", ->
  beforeEach ->
    spyOn(AppEnv, "isMainWindow").andReturn true
    ContactStore._contactCache = []
    ContactStore._fetchOffset = 0
    ContactStore._accountId = null

  describe "when searching for a contact", ->
    beforeEach ->
      @c1 = new Contact(name: "", email: "1test@nylas.com", refs: 7)
      @c2 = new Contact(name: "First", email: "2test@nylas.com", refs: 6)
      @c3 = new Contact(name: "First Last", email: "3test@nylas.com", refs: 5)
      @c4 = new Contact(name: "Fit", email: "fit@nylas.com", refs: 4)
      @c5 = new Contact(name: "Fins", email: "fins@nylas.com", refs: 3)
      @c6 = new Contact(name: "Fill", email: "fill@nylas.com", refs: 2)
      @c7 = new Contact(name: "Fin", email: "fin@nylas.com", refs: 1)

    it "can find by first name", ->
      waitsForPromise =>
        ContactStore.searchContacts("First").then (results) =>
          expect(results.length).toBe 2
          expect(results[0]).toBe @c2
          expect(results[1]).toBe @c3

    it "can find by last name", ->
      waitsForPromise =>
        ContactStore.searchContacts("Last").then (results) =>
          expect(results.length).toBe 1
          expect(results[0]).toBe @c3

    it "can find by email", ->
      waitsForPromise =>
        ContactStore.searchContacts("1test").then (results) =>
          expect(results.length).toBe 1
          expect(results[0]).toBe @c1

    it "is case insensitive", ->
      waitsForPromise =>
        ContactStore.searchContacts("FIrsT").then (results) =>
          expect(results.length).toBe 2
          expect(results[0]).toBe @c2
          expect(results[1]).toBe @c3

    it "only returns the number requested", ->
      waitsForPromise =>
        ContactStore.searchContacts("FIrsT", limit: 1).then (results) =>
          expect(results.length).toBe 1
          expect(results[0]).toBe @c2

    it "returns no more than 5 by default", ->
      waitsForPromise =>
        ContactStore.searchContacts("fi").then (results) =>
          expect(results.length).toBe 5

    it "can return more than 5 if requested", ->
      waitsForPromise =>
        ContactStore.searchContacts("fi", limit: 6).then (results) =>
          expect(results.length).toBe 6

  describe 'isValidContact', ->
    it "should call contact.isValid", ->
      contact = new Contact()
      spyOn(contact, 'isValid').andReturn(true)
      expect(ContactStore.isValidContact(contact)).toBe(true)

    it "should return false for non-Contact objects", ->
      expect(ContactStore.isValidContact({name: 'Ben', email: 'ben@nylas.com'})).toBe(false)

    it "returns false if we're not passed a contact", ->
      expect(ContactStore.isValidContact()).toBe false

  describe 'parseContactsInString', ->
    testCases =
      # Single contact test cases
      "evan@nylas.com": [new Contact(name: "evan@nylas.com", email: "evan@nylas.com")]
      "Evan Morikawa": []
      "'evan@nylas.com'": [new Contact(name: "evan@nylas.com", email: "evan@nylas.com")]
      "\"evan@nylas.com\"": [new Contact(name: "evan@nylas.com", email: "evan@nylas.com")]
      "'evan@nylas.com": [new Contact(name: "'evan@nylas.com", email: "'evan@nylas.com")]
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
      "Evan Morikawa <evan@nylas.com>; Ben <ben@nylas.com>": [
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

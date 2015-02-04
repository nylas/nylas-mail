ContactStore = require '../../src/flux/stores/contact-store'

describe "ContactStore", ->
  xit 'should return an empty array when there is no namespace', ->
    r = ContactStore.searchContacts ''
    expect(r.length).toBe 0

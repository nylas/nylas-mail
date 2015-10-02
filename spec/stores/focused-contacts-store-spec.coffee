proxyquire = require 'proxyquire'
Reflux = require 'reflux'

FocusedContactsStore = require '../../src/flux/stores/focused-contacts-store'

describe "FocusedContactsStore", ->
  beforeEach ->
    FocusedContactsStore._currentThreadId = null
    FocusedContactsStore._clearCurrentParticipants(silent: true)

  it "returns no contacts with empty", ->
    expect(FocusedContactsStore.sortedContacts()).toEqual []

  it "returns no focused contact when empty", ->
    expect(FocusedContactsStore.focusedContact()).toBeNull()

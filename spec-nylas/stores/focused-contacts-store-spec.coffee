proxyquire = require 'proxyquire'
Reflux = require 'reflux'

MessageStoreStub = Reflux.createStore
  items: -> []
  threadId: -> null

NamespaceStoreStub = Reflux.createStore
  current: -> null

FocusedContactsStore = proxyquire '../../src/flux/stores/focused-contacts-store',
  "./message-store": MessageStoreStub
  "./namespace-store": NamespaceStoreStub

describe "FocusedContactsStore", ->
  beforeEach ->
    FocusedContactsStore._currentThreadId = null
    FocusedContactsStore._clearCurrentParticipants(silent: true)

  it "returns no contacts with empty", ->
    expect(FocusedContactsStore.sortedContacts()).toEqual []

  it "returns no focused contact when empty", ->
    expect(FocusedContactsStore.focusedContact()).toBeNull()

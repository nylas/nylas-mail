_ = require 'underscore'
NamespaceStore = require '../../src/flux/stores/namespace-store'

describe "NamespaceStore", ->
  beforeEach ->
    @constructor = NamespaceStore.constructor

  it "should initialize current() using data saved in config", ->
    state =
      "id": "123",
      "email_address":"bengotow@gmail.com",
      "object":"namespace"

    spyOn(atom.config, 'get').andCallFake -> state
    instance = new @constructor
    expect(instance.current().id).toEqual(state['id'])
    expect(instance.current().emailAddress).toEqual(state['email_address'])

  it "should initialize current() to null if data is not present", ->
    spyOn(atom.config, 'get').andCallFake -> null
    instance = new @constructor
    expect(instance.current()).toEqual(null)

  it "should initialize current() to null if data is invalid", ->
    spyOn(atom.config, 'get').andCallFake -> "this isn't an object"
    instance = new @constructor
    expect(instance.current()).toEqual(null)
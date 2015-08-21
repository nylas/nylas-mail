_ = require 'underscore'
AccountStore = require '../../src/flux/stores/account-store'

describe "AccountStore", ->
  beforeEach ->
    @instance = null
    @constructor = AccountStore.constructor

  afterEach ->
    @instance.stopListeningToAll()

  it "should initialize current() using data saved in config", ->
    state =
      "id": "123",
      "email_address":"bengotow@gmail.com",
      "object":"account"
      "organization_unit": "label"

    spyOn(atom.config, 'get').andCallFake -> state
    @instance = new @constructor
    expect(@instance.current().id).toEqual(state['id'])
    expect(@instance.current().emailAddress).toEqual(state['email_address'])

  it "should initialize current() to null if data is not present", ->
    spyOn(atom.config, 'get').andCallFake -> null
    @instance = new @constructor
    expect(@instance.current()).toEqual(null)

  it "should initialize current() to null if data is invalid", ->
    spyOn(atom.config, 'get').andCallFake -> "this isn't an object"
    @instance = new @constructor
    expect(@instance.current()).toEqual(null)

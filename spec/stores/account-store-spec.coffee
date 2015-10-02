_ = require 'underscore'
AccountStore = require '../../src/flux/stores/account-store'
Account = require '../../src/flux/models/account'

describe "AccountStore", ->
  beforeEach ->
    @instance = null
    @constructor = AccountStore.constructor

  afterEach ->
    @instance.stopListeningToAll()

  it "should initialize using data saved in config", ->
    accounts =
      [{
        "id": "123",
        "client_id" : 'local-4f9d476a-c173',
        "server_id" : '123',
        "email_address":"bengotow@gmail.com",
        "object":"account"
        "organization_unit": "label"
      },{
        "id": "1234",
        "client_id" : 'local-4f9d476a-c175',
        "server_id" : '1234',
        "email_address":"ben@nylas.com",
        "object":"account"
        "organization_unit": "label"
      }]

    spyOn(atom.config, 'get').andCallFake (key) ->
      if key is 'nylas.accounts'
        return accounts
      else if key is 'nylas.currentAccountIndex'
        return 1
    @instance = new @constructor

    expect(@instance.items()).toEqual([
      (new Account).fromJSON(accounts[0]),
      (new Account).fromJSON(accounts[1])
    ])
    expect(@instance.current() instanceof Account).toBe(true)
    expect(@instance.current().id).toEqual(accounts[1]['id'])
    expect(@instance.current().emailAddress).toEqual(accounts[1]['email_address'])

  it "should initialize current() to null if data is not present", ->
    spyOn(atom.config, 'get').andCallFake -> null
    @instance = new @constructor
    expect(@instance.current()).toEqual(null)

  it "should initialize current() to null if data is invalid", ->
    spyOn(atom.config, 'get').andCallFake -> "this isn't an object"
    @instance = new @constructor
    expect(@instance.current()).toEqual(null)

  describe "adding account from json", ->
    beforeEach ->
      spyOn(atom.config, "set")
      @json =
        "id": "1234",
        "client_id" : 'local-4f9d476a-c175',
        "server_id" : '1234',
        "email_address":"ben@nylas.com",
        "object":"account"
        "auth_token": "auth-123"
        "organization_unit": "label"
      @instance = new @constructor
      spyOn(@instance, "onSelectAccountId").andCallThrough()
      spyOn(@instance, "trigger")
      @instance.addAccountFromJSON(@json)

    it "sets the tokens", ->
      expect(@instance._tokens["1234"]).toBe "auth-123"

    it "sets the accounts", ->
      account = (new Account).fromJSON(@json)
      expect(@instance._accounts.length).toBe 1
      expect(@instance._accounts[0]).toEqual account

    it "saves the config", ->
      expect(atom.config.save).toHaveBeenCalled()
      expect(atom.config.set.calls.length).toBe 4

    it "selects the account", ->
      expect(@instance._index).toBe 0
      expect(@instance.onSelectAccountId).toHaveBeenCalledWith("1234")
      expect(@instance.onSelectAccountId.calls.length).toBe 1

    it "triggers", ->
      expect(@instance.trigger).toHaveBeenCalled()
      expect(@instance.trigger.calls.length).toBe 1

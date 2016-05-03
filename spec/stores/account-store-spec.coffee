_ = require 'underscore'
keytar = require 'keytar'
AccountStore = require '../../src/flux/stores/account-store'
Account = require '../../src/flux/models/account'
Actions = require '../../src/flux/actions'


describe "AccountStore", ->
  beforeEach ->
    @instance = null
    @constructor = AccountStore.constructor
    @keys = {}
    spyOn(keytar, 'getPassword').andCallFake (service, account) =>
      @keys[account]
    spyOn(keytar, 'deletePassword').andCallFake (service, account) =>
      delete @keys[account]
    spyOn(keytar, 'replacePassword').andCallFake (service, account, pass) =>
      @keys[account] = pass

    @spyOnConfig = =>
      @configTokens = null
      @configVersion = 1
      @configAccounts =
        [{
          "id": "A",
          "client_id" : 'local-4f9d476a-c173',
          "server_id" : 'A',
          "email_address":"bengotow@gmail.com",
          "object":"account"
          "organization_unit": "label"
        },{
          "id": "B",
          "client_id" : 'local-4f9d476a-c175',
          "server_id" : 'B',
          "email_address":"ben@nylas.com",
          "object":"account"
          "organization_unit": "label"
        }]

      spyOn(NylasEnv.config, 'get').andCallFake (key) =>
        return @configAccounts if key is 'nylas.accounts'
        return @configVersion if key is 'nylas.accountsVersion'
        return @configTokens if key is 'nylas.accountTokens'
        return null

  afterEach ->
    @instance.stopListeningToAll()

  describe "initialization", ->
    beforeEach ->
      spyOn(NylasEnv.config, 'set')
      @spyOnConfig()

    it "should initialize the accounts and version from config", ->
      @instance = new @constructor
      expect(@instance._version).toEqual(@configVersion)
      expect(@instance.accounts()).toEqual([
        (new Account).fromJSON(@configAccounts[0]),
        (new Account).fromJSON(@configAccounts[1])
      ])

    it "should initialize tokens from config, if present, and save them to keytar", ->
      @configTokens = {'A': 'A-TOKEN'}
      @instance = new @constructor
      expect(@instance.tokenForAccountId('A')).toEqual('A-TOKEN')
      expect(@instance.tokenForAccountId('B')).toEqual(undefined)
      expect(keytar.replacePassword).toHaveBeenCalledWith('Nylas', 'bengotow@gmail.com', 'A-TOKEN')

    it "should initialize tokens from keytar", ->
      @configTokens = null
      jasmine.unspy(keytar, 'getPassword')
      spyOn(keytar, 'getPassword').andCallFake (service, account) =>
        return 'A-TOKEN' if account is 'bengotow@gmail.com'
        return 'B-TOKEN' if account is 'ben@nylas.com'
        return null
      @instance = new @constructor
      expect(@instance.tokenForAccountId('A')).toEqual('A-TOKEN')
      expect(@instance.tokenForAccountId('B')).toEqual('B-TOKEN')

  describe "accountForEmail", ->
    beforeEach ->
      @instance = new @constructor
      @ac1 = new Account emailAddress: 'juan@nylas.com', aliases: []
      @ac2 = new Account emailAddress: 'juan@gmail.com', aliases: ['Juan <juanchis@gmail.com>']
      @ac3 = new Account emailAddress: 'jackie@columbia.edu', aliases: ['Jackie Luo <jacqueline.luo@columbia.edu>']
      @instance._accounts = [@ac1, @ac2, @ac3]

    it 'returns correct account when no alises present', ->
      expect(@instance.accountForEmail('juan@nylas.com')).toEqual @ac1

    it 'returns correct account when alias is used', ->
      expect(@instance.accountForEmail('juanchis@gmail.com')).toEqual @ac2
      expect(@instance.accountForEmail('jacqueline.luo@columbia.edu')).toEqual @ac3

  describe "adding account from json", ->
    beforeEach ->
      @json =
        "id": "B",
        "client_id" : 'local-4f9d476a-c175',
        "server_id" : 'B',
        "email_address":"ben@nylas.com",
        "provider":"gmail",
        "object":"account"
        "auth_token": "B-NEW-TOKEN"
        "organization_unit": "label"
      @instance = new @constructor
      spyOn(NylasEnv.config, "set")
      spyOn(Actions, 'focusDefaultMailboxPerspectiveForAccounts')
      spyOn(@instance, "trigger")
      @instance.addAccountFromJSON(@json)

    it "saves the token to keytar and to the loaded tokens cache", ->
      expect(@instance._tokens["B"]).toBe("B-NEW-TOKEN")
      expect(keytar.replacePassword).toHaveBeenCalledWith("Nylas", "ben@nylas.com", "B-NEW-TOKEN")

    it "saves the account to the accounts cache and saves", ->
      account = (new Account).fromJSON(@json)
      expect(@instance._accounts.length).toBe 1
      expect(@instance._accounts[0]).toEqual account
      expect(NylasEnv.config.set.calls.length).toBe 3
      expect(NylasEnv.config.set.calls[2].args).toEqual(['nylas.accountTokens', null])
      expect(NylasEnv.config.save).toHaveBeenCalled()

    it "selects the account", ->
      expect(Actions.focusDefaultMailboxPerspectiveForAccounts).toHaveBeenCalledWith(["B"])

    it "triggers", ->
      expect(@instance.trigger).toHaveBeenCalled()

    describe "when an account with the same ID is already present", ->
      it "should update it", ->
        @json =
          "id": "B",
          "client_id" : 'local-4f9d476a-c175',
          "server_id" : 'B',
          "email_address":"ben@nylas.com",
          "provider":"gmail",
          "object":"account"
          "auth_token": "B-NEW-TOKEN"
          "organization_unit": "label"
        @spyOnConfig()
        @instance = new @constructor
        spyOn(@instance, "trigger")
        expect(@instance._accounts.length).toBe 2
        @instance.addAccountFromJSON(@json)
        expect(@instance._accounts.length).toBe 2

    describe "when an account with the same email, but different ID, is already present", ->
      it "should update it", ->
        @json =
          "id": "NEVER SEEN BEFORE",
          "client_id" : 'local-4f9d476a-c175',
          "server_id" : 'NEVER SEEN BEFORE',
          "email_address":"ben@nylas.com",
          "provider":"gmail",
          "object":"account"
          "auth_token": "B-NEW-TOKEN"
          "organization_unit": "label"
        @spyOnConfig()
        @instance = new @constructor
        spyOn(@instance, "trigger")
        expect(@instance._accounts.length).toBe 2
        @instance.addAccountFromJSON(@json)
        expect(@instance._accounts.length).toBe 2
        expect(@instance.accountForId('B')).toBe(undefined)
        expect(@instance.accountForId('NEVER SEEN BEFORE')).not.toBe(undefined)

_ = require 'underscore'
KeyManager = require('../../src/key-manager').default
NylasAPI = require('../../src/flux/nylas-api').default
NylasAPIRequest = require('../../src/flux/nylas-api-request').default
AccountStore = require('../../src/flux/stores/account-store').default
Account = require('../../src/flux/models/account').default
Actions = require('../../src/flux/actions').default

xdescribe "AccountStore", ->
  beforeEach ->
    @instance = null
    @constructor = AccountStore.constructor
    @keys = {}
    spyOn(KeyManager, 'getPassword').andCallFake (account) =>
      @keys[account]
    spyOn(KeyManager, 'deletePassword').andCallFake (account) =>
      delete @keys[account]
    spyOn(KeyManager, 'replacePassword').andCallFake (account, pass) =>
      @keys[account] = pass

    @spyOnConfig = =>
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
        return 'production' if key is 'env'
        return @configAccounts if key is 'nylas.accounts'
        return @configVersion if key is 'nylas.accountsVersion'
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

    it "should initialize tokens from KeyManager", ->
      jasmine.unspy(KeyManager, 'getPassword')
      spyOn(KeyManager, 'getPassword').andCallFake (account) =>
        return 'AL-TOKEN' if account is 'bengotow@gmail.com.localSync'
        return 'AC-TOKEN' if account is 'bengotow@gmail.com.n1Cloud'
        return 'BL-TOKEN' if account is 'ben@nylas.com.localSync'
        return 'BC-TOKEN' if account is 'ben@nylas.com.n1Cloud'
        return null
      @instance = new @constructor
      expect(@instance.tokensForAccountId('A')).toEqual({localSync: 'AL-TOKEN', n1Cloud: 'AC-TOKEN'})
      expect(@instance.tokensForAccountId('B')).toEqual({localSync: 'BL-TOKEN', n1Cloud: 'BC-TOKEN'})

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
        "object":"account",
        "organization_unit": "label",
      @instance = new @constructor
      spyOn(NylasEnv.config, "set")
      spyOn(@instance, "trigger")
      @instance.addAccountFromJSON(@json, "LOCAL_TOKEN", "CLOUD_TOKEN")

    it "saves the token to KeyManager and to the loaded tokens cache", ->
      expect(@instance._tokens["B"]).toEqual({n1Cloud: "CLOUD_TOKEN", localSync: "LOCAL_TOKEN"})
      expect(KeyManager.replacePassword).toHaveBeenCalledWith("ben@nylas.com.localSync", "LOCAL_TOKEN")
      expect(KeyManager.replacePassword).toHaveBeenCalledWith("ben@nylas.com.n1Cloud", "CLOUD_TOKEN")

    it "saves the account to the accounts cache and saves", ->
      account = (new Account).fromJSON(@json)
      expect(@instance._accounts.length).toBe 1
      expect(@instance._accounts[0]).toEqual account
      expect(NylasEnv.config.set.calls.length).toBe 3
      expect(NylasEnv.config.set.calls[0].args).toEqual(['nylas.accountTokens', null])
      # Version must be updated last since it will trigger other windows to load nylas.accounts
      expect(NylasEnv.config.set.calls[2].args).toEqual(['nylas.accountsVersion', 1])

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
          "organization_unit": "label"
        @spyOnConfig()
        @instance = new @constructor
        spyOn(@instance, "trigger")
        expect(@instance._accounts.length).toBe 2
        @instance.addAccountFromJSON(@json, "B-NEW-LOCAL-TOKEN", "B-NEW-CLOUD-TOKEN")
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
          "organization_unit": "label"
        @spyOnConfig()
        @instance = new @constructor
        spyOn(@instance, "trigger")
        expect(@instance._accounts.length).toBe 2
        @instance.addAccountFromJSON(@json, "B-NEW-LOCAL-TOKEN", "B-NEW-CLOUD-TOKEN")
        expect(@instance._accounts.length).toBe 2
        expect(@instance.accountForId('B')).toBe(undefined)
        expect(@instance.accountForId('NEVER SEEN BEFORE')).not.toBe(undefined)

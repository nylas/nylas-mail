_ = require 'underscore'
keytar = require 'keytar'
NylasAPI = require '../../src/flux/nylas-api'
NylasAPIRequest = require('../../src/flux/nylas-api-request').default
AccountStore = require '../../src/flux/stores/account-store'
Account = require('../../src/flux/models/account').default
Actions = require('../../src/flux/actions').default


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

    it "should initialize tokens from keytar", ->
      jasmine.unspy(keytar, 'getPassword')
      spyOn(keytar, 'getPassword').andCallFake (service, account) =>
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

    it "saves the token to keytar and to the loaded tokens cache", ->
      expect(@instance._tokens["B"]).toEqual({n1Cloud: "CLOUD_TOKEN", localSync: "LOCAL_TOKEN"})
      expect(keytar.replacePassword).toHaveBeenCalledWith("Nylas", "ben@nylas.com.localSync", "LOCAL_TOKEN")
      expect(keytar.replacePassword).toHaveBeenCalledWith("Nylas", "ben@nylas.com.n1Cloud", "CLOUD_TOKEN")

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

  describe "refreshHealthOfAccounts", ->
    beforeEach ->
      @spyOnConfig()
      @calledOptions = calledOptions = []

      spyOn(NylasAPIRequest.prototype, 'run').andCallFake () ->
        options = this.options
        calledOptions.push(this.options)
        if options.accountId is 'return-api-error'
          Promise.reject(new Error("API ERROR"))
        else
          Promise.resolve({
            sync_state: 'running',
            id: options.accountId,
            account_id: options.accountId
          })
      @instance = new @constructor
      spyOn(@instance, '_save')

    it "should GET /account for each of the provided account IDs", ->
      @instance.refreshHealthOfAccounts(['A', 'B'])
      expect(NylasAPIRequest.prototype.run.callCount).toBe(2)
      expect(@calledOptions[0].path).toEqual('/account')
      expect(@calledOptions[0].accountId).toEqual('A')
      expect(@calledOptions[1].path).toEqual('/account')
      expect(@calledOptions[1].accountId).toEqual('B')

    it "should update existing account objects and call save exactly once", ->
      @instance.accountForId('A').syncState = 'invalid'
      @instance.refreshHealthOfAccounts(['A', 'B'])
      advanceClock()
      expect(@instance.accountForId('A').syncState).toEqual('running')
      expect(@instance._save.callCount).toBe(1)

    it "should ignore accountIds which do not exist locally when the request completes", ->
      @instance.accountForId('A').syncState = 'invalid'
      @instance.refreshHealthOfAccounts(['gone', 'A', 'B'])
      advanceClock()
      expect(@instance.accountForId('A').syncState).toEqual('running')
      expect(@instance._save.callCount).toBe(1)

    it "should not stop if a single GET /account fails", ->
      @instance.accountForId('B').syncState = 'invalid'
      @instance.refreshHealthOfAccounts(['return-api-error', 'B']).catch (e) =>
      advanceClock()
      expect(@instance.accountForId('B').syncState).toEqual('running')
      expect(@instance._save.callCount).toBe(1)

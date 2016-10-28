_ = require 'underscore'
keytar = require 'keytar'
NylasAPI = require '../../src/flux/nylas-api'
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
        return 'production' if key is 'env'
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

  describe "refreshHealthOfAccounts", ->
    beforeEach ->
      @spyOnConfig()
      spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
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
      expect(NylasAPI.makeRequest.callCount).toBe(2)
      expect(NylasAPI.makeRequest.calls[0].args).toEqual([{path: '/account', accountId: 'A'}])
      expect(NylasAPI.makeRequest.calls[1].args).toEqual([{path: '/account', accountId: 'B'}])

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

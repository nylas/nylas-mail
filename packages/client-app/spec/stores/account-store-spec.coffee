_ = require 'underscore'
KeyManager = require('../../src/key-manager').default
NylasAPI = require('../../src/flux/nylas-api').default
NylasAPIRequest = require('../../src/flux/nylas-api-request').default
AccountStore = require('../../src/flux/stores/account-store').default
Account = require('../../src/flux/models/account').default
Actions = require('../../src/flux/actions').default

describe "AccountStore", ->
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
          "aliases": ["Alias <alias@nylas.com>"]
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
      expect(NylasEnv.config.set.calls.length).toBe 2
      expect(NylasEnv.config.set.calls[0].args).toEqual(['nylas.accounts', [account.toJSON()]])
      # Version must be updated last since it will trigger other windows to load nylas.accounts
      expect(NylasEnv.config.set.calls[1].args).toEqual(['nylas.accountsVersion', 1])

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

  describe "handleAuthenticationFailure", ->
    beforeEach ->
      spyOn(NylasEnv.config, 'set')
      @spyOnConfig()
      @instance = new @constructor
      spyOn(@instance, "trigger")
      @instance._tokens =
        "A":
          localSync: 'token'
          n1Cloud: 'token'
        "B":
          localSync: 'token'
          n1Cloud: 'token'

    it "should put the account in an `invalid` state", ->
      spyOn(@instance, "_onUpdateAccount")
      spyOn(AccountStore, 'tokensForAccountId').andReturn({localSync: 'token'})
      @instance._onAPIAuthError(new Error(), auth: user: 'token')
      expect(@instance._onUpdateAccount).toHaveBeenCalled()
      expect(@instance._onUpdateAccount.callCount).toBe(1)
      expect(@instance._onUpdateAccount.mostRecentCall.args).toEqual(['A', {syncState: 'invalid'}])

    it "should put the N1 Cloud account in an `invalid` state", ->
      spyOn(@instance, "_onUpdateAccount")
      spyOn(AccountStore, 'tokensForAccountId').andReturn({n1Cloud: 'token'})
      @instance._onAPIAuthError(new Error(), auth: user: 'token', 'N1CloudAPI')
      expect(@instance._onUpdateAccount).toHaveBeenCalled()
      expect(@instance._onUpdateAccount.mostRecentCall.args).toEqual(['A', {syncState: 'n1_cloud_auth_failed'}])

    it "should not throw an exception if the account cannot be found", ->
      spyOn(@instance, "_onUpdateAccount")
      @instance._onAPIAuthError(new Error(), auth: user: 'not found')
      expect(@instance._onUpdateAccount).not.toHaveBeenCalled()

  describe "isMyEmail", ->
    beforeEach ->
      spyOn(NylasEnv.config, 'set')
      @spyOnConfig()
      @instance = new @constructor

    it "works with account emails", ->
      expect(@instance.isMyEmail("bengotow@gmail.com")).toBe(true)
      expect(@instance.isMyEmail("ben@nylas.com")).toBe(true)
      expect(@instance.isMyEmail("foo@bar.com")).toBe(false)
      expect(@instance.isMyEmail("ben@gmail.com")).toBe(false)

    it "works with multiple emails", ->
      expect(@instance.isMyEmail(["bengotow@gmail.com", "ben@nylas.com"])).toBe(true)
      expect(@instance.isMyEmail(["bengotow@gmail.com", "foo@bar.com"])).toBe(true)
      expect(@instance.isMyEmail(["blah@gmail.com", "foo@bar.com"])).toBe(false)

    it "works with aliases", ->
      expect(@instance.isMyEmail("alias@nylas.com")).toBe(true)
      expect(@instance.isMyEmail("foo@bar.com")).toBe(false)

    it "works with miscased emails", ->
      expect(@instance.isMyEmail("Bengotow@Gmail.com")).toBe(true)
      expect(@instance.isMyEmail("Ben@Nylas.com  ")).toBe(true)

    it "works with plus aliases", ->
      expect(@instance.isMyEmail("bengotow+stuff@gmail.com")).toBe(true)
      expect(@instance.isMyEmail("ben+bar+baz@nylas.com")).toBe(true)
      expect(@instance.isMyEmail("ben=stuff@nylas.com")).toBe(false)

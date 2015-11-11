Actions = require '../lib/onboarding-actions'
NylasApiEnvironmentStore = require '../lib/nylas-api-environment-store'
storeConstructor = NylasApiEnvironmentStore.constructor

describe "NylasApiEnvironmentStore", ->
  beforeEach ->
    spyOn(NylasEnv.config, "set")

  it "doesn't set if it alreayd exists", ->
    spyOn(NylasEnv.config, "get").andReturn "staging"
    store = new storeConstructor()
    expect(NylasEnv.config.set).not.toHaveBeenCalled()

  it "initializes with the correct default in dev mode", ->
    spyOn(NylasEnv, "inDevMode").andReturn true
    spyOn(NylasEnv.config, "get").andReturn undefined
    store = new storeConstructor()
    expect(NylasEnv.config.set).toHaveBeenCalledWith("env", "production")

  it "initializes with the correct default in production", ->
    spyOn(NylasEnv, "inDevMode").andReturn false
    spyOn(NylasEnv.config, "get").andReturn undefined
    store = new storeConstructor()
    expect(NylasEnv.config.set).toHaveBeenCalledWith("env", "production")

  describe "when setting the environment", ->
    it "sets from the desired action", ->
      Actions.changeAPIEnvironment("staging")
      expect(NylasEnv.config.set).toHaveBeenCalledWith("env", "staging")

    it "throws if the env is invalid", ->
      expect( -> Actions.changeAPIEnvironment("bad")).toThrow()

    it "throws if the env is blank", ->
      expect( -> Actions.changeAPIEnvironment()).toThrow()

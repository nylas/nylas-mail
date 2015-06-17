Actions = require '../lib/onboarding-actions'
NylasApiEnvironmentStore = require '../lib/nylas-api-environment-store'
storeConstructor = NylasApiEnvironmentStore.constructor

describe "NylasApiEnvironmentStore", ->
  beforeEach ->
    spyOn(atom.config, "set")

  it "doesn't set if it alreayd exists", ->
    spyOn(atom.config, "get").andReturn "staging"
    store = new storeConstructor()
    expect(atom.config.set).not.toHaveBeenCalled()

  it "initializes with the correct default in dev mode", ->
    spyOn(atom, "inDevMode").andReturn true
    spyOn(atom.config, "get").andReturn undefined
    store = new storeConstructor()
    expect(atom.config.set).toHaveBeenCalledWith("env", "staging")

  it "initializes with the correct default in production", ->
    spyOn(atom, "inDevMode").andReturn false
    spyOn(atom.config, "get").andReturn undefined
    store = new storeConstructor()
    expect(atom.config.set).toHaveBeenCalledWith("env", "staging")

  describe "when setting the environment", ->
    it "sets from the desired action", ->
      Actions.changeAPIEnvironment("production")
      expect(atom.config.set).toHaveBeenCalledWith("env", "production")

    it "throws if the env is invalid", ->
      expect( -> Actions.changeAPIEnvironment("bad")).toThrow()

    it "throws if the env is blank", ->
      expect( -> Actions.changeAPIEnvironment()).toThrow()

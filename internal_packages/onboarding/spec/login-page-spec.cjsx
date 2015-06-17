_ = require "underscore"
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

LoginPage = require '../lib/login-page'
OnboardingActions = require '../lib/onboarding-actions'

describe "LoginPage", ->

  it "shows env picker in Dev Mode", ->
    spyOn(atom, "inDevMode").andReturn true
    @loginPage = ReactTestUtils.renderIntoDocument(<LoginPage />)
    picker = ReactTestUtils.findRenderedDOMComponentWithClass(@loginPage, "environment-selector")
    expect(picker).toBeDefined()

  it "hides env picker in other modes", ->
    spyOn(atom, "inDevMode").andReturn false
    @loginPage = ReactTestUtils.renderIntoDocument(<LoginPage />)
    expect(-> ReactTestUtils.findRenderedDOMComponentWithClass(@loginPage, "environment-selector")).toThrow()

  it 'can change the environment', ->
    spyOn(atom, "inDevMode").andReturn true
    spyOn(OnboardingActions, "changeAPIEnvironment")
    @loginPage = ReactTestUtils.renderIntoDocument(<LoginPage />)
    sel = ReactTestUtils.findRenderedDOMComponentWithTag(@loginPage, "select")
    ReactTestUtils.Simulate.change(sel, {target: {value: 'staging'}})
    expect(OnboardingActions.changeAPIEnvironment).toHaveBeenCalledWith("staging")

  describe "logging in", ->
    beforeEach ->
      @connectURL = "foo"
      spyOn(OnboardingActions, "moveToPage")
      @loginPage = ReactTestUtils.renderIntoDocument(<LoginPage />)

    hasEmail = (email) ->
      page = OnboardingActions.moveToPage.calls[0].args[0]
      data = OnboardingActions.moveToPage.calls[0].args[1]
      expect(page).toBe "add-account-auth"
      expect(data.url.length).toBeGreaterThan 0

    it "submits information when the form submits", ->
      @loginPage.setState email: "test@nylas.com"
      form = ReactTestUtils.findRenderedDOMComponentWithClass(@loginPage, 'email-form')
      ReactTestUtils.Simulate.submit(form)
      hasEmail("test@nylas.com")

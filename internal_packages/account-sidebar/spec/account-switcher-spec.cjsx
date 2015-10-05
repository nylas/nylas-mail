React = require 'react/addons'
TestUtils = React.addons.TestUtils
AccountSwitcher = require './../lib/account-switcher'
{AccountStore} = require 'nylas-exports'

describe "AccountSwitcher", ->
  switcher = null

  beforeEach ->
    spyOn(AccountStore, "items").andCallFake ->
      [
        AccountStore.current(),
        {
          emailAddress: "dillon@nylas.com",
          provider: "exchange"
        }
      ]

    switcher = TestUtils.renderIntoDocument(
      <AccountSwitcher />
    )

  it "doesn't render the dropdown if nothing clicked", ->
    openDropdown = TestUtils.scryRenderedDOMComponentsWithClass switcher, 'open'
    expect(openDropdown.length).toBe 0

  it "shows the dropdown on click", ->
    toggler = TestUtils.findRenderedDOMComponentWithClass switcher, 'primary-item'
    TestUtils.Simulate.click toggler
    openDropdown = TestUtils.scryRenderedDOMComponentsWithClass switcher, 'open'
    expect(openDropdown.length).toBe 1

  it "hides the dropdown on blur", ->
    toggler = TestUtils.findRenderedDOMComponentWithClass switcher, 'primary-item'
    TestUtils.Simulate.click toggler
    toggler = TestUtils.findRenderedDOMComponentWithClass switcher, 'primary-item'
    TestUtils.Simulate.blur toggler
    openDropdown = TestUtils.scryRenderedDOMComponentsWithClass switcher, 'open'
    expect(openDropdown.length).toBe 0

  it "shows other accounts and the 'Add Account' button", ->
    toggler = TestUtils.findRenderedDOMComponentWithClass switcher, 'primary-item'
    TestUtils.Simulate.click toggler

    dropdown = TestUtils.findRenderedDOMComponentWithClass switcher, "dropdown"
    items = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "secondary-item"
    newAccountButton = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "new-account-option"

    expect(items.length).toBe 3
    expect(newAccountButton.length).toBe 1

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
          label: "work"
        }
      ]

    switcher = TestUtils.renderIntoDocument(
      <AccountSwitcher />
    )

  it "shows other accounts and the 'Add Account' button", ->
    toggler = TestUtils.findRenderedDOMComponentWithClass switcher, 'primary-item'
    TestUtils.Simulate.click toggler

    dropdown = TestUtils.findRenderedDOMComponentWithClass switcher, "dropdown"
    items = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "secondary-item"
    newAccountButton = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "new-account-option"

    expect(items.length).toBe 3
    expect(newAccountButton.length).toBe 1

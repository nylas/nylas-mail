React = require 'react/addons'
TestUtils = React.addons.TestUtils
AccountSwitcher = require './../lib/account-switcher'
{AccountStore, Label} = require 'nylas-exports'

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
          categoryClass: -> Label
        }
      ]

    switcher = TestUtils.renderIntoDocument(
      <AccountSwitcher />
    )

  it "shows other accounts and the 'Add Account' button", ->
    items = TestUtils.scryRenderedDOMComponentsWithClass switcher, "secondary-item"
    newAccountButton = TestUtils.scryRenderedDOMComponentsWithClass switcher, "new-account-option"

    expect(items.length).toBe 3
    expect(newAccountButton.length).toBe 1

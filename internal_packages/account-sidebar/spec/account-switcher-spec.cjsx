React = require 'react/addons'
TestUtils = React.addons.TestUtils
AccountSwitcher = require './../lib/account-switcher'
AccountSidebarStore = require './../lib/account-sidebar-store'
{AccountStore} = require 'nylas-exports'

fdescribe "AccountSwitcher", ->
  switcher = null

  beforeEach ->
    account = AccountStore.accounts()[0]
    spyOn(AccountStore, "accounts").andReturn [
      account,
      {
        emailAddress: "dillon@nylas.com",
        provider: "exchange"
        label: "work"
      }
    ]
    spyOn(AccountSidebarStore, "currentAccount").andReturn account

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

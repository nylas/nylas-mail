React = require 'react/addons'
TestUtils = React.addons.TestUtils
AccountSwitcher = require './../lib/components/account-switcher'
SidebarStore = require './../lib/sidebar-store'
{AccountStore} = require 'nylas-exports'

describe "AccountSwitcher", ->
  switcher = null

  beforeEach ->
    account = AccountStore.accounts()[0]
    accounts = [
      account,
      {
        emailAddress: "dillon@nylas.com",
        provider: "exchange"
        label: "work"
      }
    ]
    switcher = TestUtils.renderIntoDocument(
      <AccountSwitcher accounts={accounts} focusedAccounts={[account]} />
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

     # The unified Inbox item, then both accounts, then the manage item
    expect(items.length).toBe 4
    expect(newAccountButton.length).toBe 1

React = require 'react/addons'
TestUtils = React.addons.TestUtils
AccountSidebar = require './../lib/account-sidebar'
{AccountStore} = require 'nylas-exports'

describe "AccountSidebar", ->
  describe "account switcher", ->
    sidebar = null

    beforeEach ->
      spyOn(AccountStore, "items").andCallFake ->
        [
          AccountStore.current(),
          {
            emailAddress: "dillon@nylas.com",
            provider: "exchange"
          }
        ]

      sidebar = TestUtils.renderIntoDocument(
        <AccountSidebar />
      )

    it "doesn't render the dropdown if nothing clicked", ->
      dropdown = TestUtils.findRenderedDOMComponentWithClass sidebar, "dropdown"
      dropdownNode = React.findDOMNode dropdown, "account-switcher-dropdown"

      expect(dropdownNode.style.display).toBe "none"

    it "renders the dropdown if clicking the arrow btn", ->
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.click toggler
      dropdown = TestUtils.findRenderedDOMComponentWithClass sidebar, "dropdown"
      dropdownNode = React.findDOMNode dropdown, "account-switcher-dropdown"

      expect(dropdownNode.style.display).toBe "block"

    it "removes the dropdown when clicking elsewhere", ->
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.blur toggler
      dropdown = TestUtils.findRenderedDOMComponentWithClass sidebar, "dropdown"
      dropdownNode = React.findDOMNode dropdown, "account-switcher-dropdown"

      expect(dropdownNode.style.display).toBe "none"

    it "shows all the accounts in the dropdown", ->
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.click toggler
      dropdown = TestUtils.findRenderedDOMComponentWithClass sidebar, "dropdown"
      accounts = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "account-option"

      expect(accounts.length).toBe 2

    it "shows the 'Add Account' button too", ->
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.click toggler
      dropdown = TestUtils.findRenderedDOMComponentWithClass sidebar, "dropdown"
      accounts = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "new-account-option"

      expect(accounts.length).toBe 1

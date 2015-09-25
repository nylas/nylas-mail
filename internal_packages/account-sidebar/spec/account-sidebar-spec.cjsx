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
      openDropdown = TestUtils.scryRenderedDOMComponentsWithClass sidebar, 'open'
      expect(openDropdown.length).toBe 0

    it "shows the dropdown on click", ->
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.click toggler
      openDropdown = TestUtils.scryRenderedDOMComponentsWithClass sidebar, 'open'
      expect(openDropdown.length).toBe 1

    it "hides the dropdown on blur", ->
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.click toggler
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.blur toggler
      openDropdown = TestUtils.scryRenderedDOMComponentsWithClass sidebar, 'open'
      expect(openDropdown.length).toBe 0

    it "shows other accounts and the 'Add Account' button", ->
      toggler = TestUtils.findRenderedDOMComponentWithClass sidebar, 'primary-item'
      TestUtils.Simulate.click toggler

      dropdown = TestUtils.findRenderedDOMComponentWithClass sidebar, "dropdown"
      items = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "secondary-item"
      newAccountButton = TestUtils.scryRenderedDOMComponentsWithClass dropdown, "new-account-option"

      expect(items.length).toBe 3
      expect(newAccountButton.length).toBe 1

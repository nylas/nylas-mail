React = require 'react/addons'
ReactTestUtils = React.addons.TestUtils
MessageToolbarItems = require "../lib/message-toolbar-items.cjsx"
{WorkspaceStore, Actions} = require 'inbox-exports'

describe "MessageToolbarItems", ->
  beforeEach ->
    @toolbarItems = ReactTestUtils.renderIntoDocument(<MessageToolbarItems />)
    @archiveButton = @toolbarItems.refs["archiveButton"]
    spyOn(Actions, "archiveAndNext")
    spyOn(Actions, "archive")

  it "renders the archive button", ->
    btns = ReactTestUtils.scryRenderedDOMComponentsWithClass(@toolbarItems, "btn-archive")
    expect(btns.length).toBe 1

  it "archives in split mode", ->
    spyOn(WorkspaceStore, "layoutMode").andReturn "split"
    ReactTestUtils.Simulate.click(React.findDOMNode(@archiveButton))
    expect(Actions.archive).toHaveBeenCalled()

  it "archives in list mode", ->
    spyOn(WorkspaceStore, "layoutMode").andReturn "list"
    ReactTestUtils.Simulate.click(React.findDOMNode(@archiveButton))
    expect(Actions.archive).toHaveBeenCalled()

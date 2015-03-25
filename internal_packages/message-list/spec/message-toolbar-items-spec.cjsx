React = require 'react/addons'
ReactTestUtils = React.addons.TestUtils
MessageToolbarItems = require "../lib/message-toolbar-items.cjsx"
{WorkspaceStore, Actions} = require 'inbox-exports'

describe "MessageToolbarItems", ->
  beforeEach ->
    @toolbarItems = ReactTestUtils.renderIntoDocument(<MessageToolbarItems />)
    @archiveButton = @toolbarItems.refs["archiveButton"]
    spyOn(Actions, "archiveAndNext")
    spyOn(Actions, "archiveCurrentThread")

  it "renders the archive button", ->
    btns = ReactTestUtils.scryRenderedDOMComponentsWithClass(@toolbarItems, "btn-archive")
    expect(btns.length).toBe 1

  it "archives and next in split mode", ->
    spyOn(WorkspaceStore, "selectedLayoutMode").andReturn "split"
    ReactTestUtils.Simulate.click(@archiveButton.getDOMNode())
    expect(Actions.archiveCurrentThread).not.toHaveBeenCalled()
    expect(Actions.archiveAndNext).toHaveBeenCalled()

  it "archives in list mode", ->
    spyOn(WorkspaceStore, "selectedLayoutMode").andReturn "list"
    ReactTestUtils.Simulate.click(@archiveButton.getDOMNode())
    expect(Actions.archiveCurrentThread).toHaveBeenCalled()
    expect(Actions.archiveAndNext).not.toHaveBeenCalled()

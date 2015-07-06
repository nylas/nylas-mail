{React} = require 'nylas-exports'
ReactTestUtils = React.addons.TestUtils

MyComposerButton = require '../lib/my-composer-button'

dialogStub =
  showMessageBox: jasmine.createSpy('showMessageBox')

describe "MyComposerButton", ->
  beforeEach ->
    @component = ReactTestUtils.renderIntoDocument(
      <MyComposerButton draftLocalId="test" />
    )

  it "should render into the page", ->
    expect(@component).toBeDefined()

  it "should have a displayName", ->
    expect(MyComposerButton.displayName).toBe('MyComposerButton')

  it "should show a dialog box when clicked", ->
    spyOn(@component, '_onClick')
    buttonNode = React.findDOMNode(@component.refs.button)
    ReactTestUtils.Simulate.click(buttonNode)
    expect(@component._onClick).toHaveBeenCalled()
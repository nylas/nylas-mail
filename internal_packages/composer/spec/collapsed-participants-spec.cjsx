_ = require "underscore"
React = require "react/addons"
Fields = require '../lib/fields'
ReactTestUtils = React.addons.TestUtils
CollapsedParticipants = require '../lib/collapsed-participants'

{Contact} = require 'nylas-exports'

describe "CollapsedParticipants", ->
  makeField = (props={}) ->
    @onClick = jasmine.createSpy("onClick")
    props.onClick = @onClick
    @fields = ReactTestUtils.renderIntoDocument(
      <CollapsedParticipants {...props} />
    )

  it "fires callback when clicked", ->
    makeField.call(@)
    ReactTestUtils.Simulate.click React.findDOMNode(@fields)
    expect(@onClick).toHaveBeenCalled()
    expect(@onClick.calls.length).toBe 1

  numStr = ->
    React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "num-remaining")).innerHTML

  it "doesn't render num remaining when nothing remains", ->
    makeField.call(@)
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@fields, "num-remaining")
    expect(els.length).toBe 0

  it "renders num remaining when remaining with no bcc", ->
    makeField.call(@)
    spyOn(@fields, "_setNumHiddenParticipants")
    @fields.setState numRemaining: 10, numBccRemaining: 0
    str = numStr.call(@)
    expect(str).toBe "10 more"

  it "renders num remaining when only bcc", ->
    makeField.call(@)
    spyOn(@fields, "_setNumHiddenParticipants")
    @fields.setState numRemaining: 0, numBccRemaining: 5
    str = numStr.call(@)
    expect(str).toBe "5 Bcc"

  it "renders num remaining when both remaining andj bcc", ->
    makeField.call(@)
    spyOn(@fields, "_setNumHiddenParticipants")
    @fields.setState numRemaining: 10, numBccRemaining: 5
    str = numStr.call(@)
    expect(str).toBe "15 more (5 Bcc)"

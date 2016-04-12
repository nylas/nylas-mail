_ = require "underscore"
React = require "react"
ReactDOM = require 'react-dom'
ReactTestUtils = require 'react-addons-test-utils'

Fields = require '../lib/fields'
CollapsedParticipants = require '../lib/collapsed-participants'

{Contact} = require 'nylas-exports'

describe "CollapsedParticipants", ->
  makeField = (props={}) ->
    @fields = ReactTestUtils.renderIntoDocument(
      <CollapsedParticipants {...props} />
    )

  numStr = ->
    ReactDOM.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "num-remaining")).innerHTML

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

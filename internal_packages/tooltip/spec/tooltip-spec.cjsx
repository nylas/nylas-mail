# Testing the Tooltip component
_ = require 'underscore-plus'
React = require 'react/addons'
ReactTestUtils = React.addons.TestUtils

Tooltip = require '../lib/tooltip.cjsx'

describe "Tooltip", ->
  beforeEach ->
    @tooltip = ReactTestUtils.renderIntoDocument(
      <Tooltip />
    )

  it "renders to the document", ->
    expect(ReactTestUtils.isCompositeComponentWithType @tooltip, Tooltip).toBe true

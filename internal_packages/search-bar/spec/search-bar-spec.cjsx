React = require 'react'
ReactTestUtils = React.addons.TestUtils

SearchBar = require '../lib/search-bar'
SearchActions = require '../lib/search-actions'
SearchSuggestionStore = require '../lib/search-suggestion-store'

describe 'SearchBar', ->
  beforeEach ->
    spyOn(NylasEnv, "isMainWindow").andReturn true
    @searchBar = ReactTestUtils.renderIntoDocument(<SearchBar />)
    input = ReactTestUtils.findRenderedDOMComponentWithTag(@searchBar, "input")
    @input = React.findDOMNode(input)

  it 'supports search queries with a colon character', ->
    spyOn(SearchActions, "queryChanged")
    test = "::Hello: World::"
    ReactTestUtils.Simulate.change @input, target: value: test
    expect(SearchActions.queryChanged).toHaveBeenCalledWith([all: test])

  it 'preserves capitalization on searches', ->
    test = "HeLlO wOrLd"
    ReactTestUtils.Simulate.change @input, target: value: test
    waitsFor =>
      @input.value.length > 0
    runs =>
      expect(@input.value).toBe(test)

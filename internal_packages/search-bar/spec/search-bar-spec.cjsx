React = require 'react'
ReactTestUtils = React.addons.TestUtils

{Actions} = require 'inbox-exports'

SearchBar = require '../lib/search-bar'
SearchSuggestionStore = require '../lib/search-suggestion-store.coffee'

describe 'SearchBar', ->
  beforeEach ->
    @searchBar = ReactTestUtils.renderIntoDocument(<SearchBar />)
    input = ReactTestUtils.findRenderedDOMComponentWithTag(@searchBar, "input")
    @input = React.findDOMNode(input)

  it 'supports search queries with a colon character', ->
    spyOn(Actions, "searchQueryChanged")
    test = "::Hello: World::"
    ReactTestUtils.Simulate.change @input, target: value: test
    expect(Actions.searchQueryChanged).toHaveBeenCalledWith [all: test]

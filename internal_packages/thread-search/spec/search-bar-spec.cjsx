React = require 'react'
ReactDOM = require 'react-dom'
ReactTestUtils = require('react-addons-test-utils')

SearchBar = require '../lib/search-bar'
SearchActions = require '../lib/search-actions'

describe 'SearchBar', ->
  beforeEach ->
    spyOn(NylasEnv, "isMainWindow").andReturn true
    @searchBar = ReactTestUtils.renderIntoDocument(<SearchBar />)
    @input = ReactDOM.findDOMNode(@searchBar).querySelector("input")

  it 'supports search queries with a colon character', ->
    spyOn(SearchActions, "queryChanged")
    test = "::Hello: World::"
    ReactTestUtils.Simulate.change @input, target: value: test
    expect(SearchActions.queryChanged).toHaveBeenCalledWith(test)

  it 'preserves capitalization on searches', ->
    test = "HeLlO wOrLd"
    ReactTestUtils.Simulate.change @input, target: value: test
    waitsFor =>
      @input.value.length > 0
    runs =>
      expect(@input.value).toBe(test)

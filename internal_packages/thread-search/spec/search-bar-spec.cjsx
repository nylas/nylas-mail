React = require 'react'
ReactDOM = require 'react-dom'
ReactTestUtils = require('react-addons-test-utils')

ThreadSearchBar = require('../lib/thread-search-bar').default
SearchActions = require('../lib/search-actions').default

describe 'ThreadSearchBar', ->
  beforeEach ->
    spyOn(NylasEnv, "isMainWindow").andReturn true
    @searchBar = ReactTestUtils.renderIntoDocument(<ThreadSearchBar />)
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

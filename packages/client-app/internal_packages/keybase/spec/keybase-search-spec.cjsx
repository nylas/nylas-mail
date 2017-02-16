{React, ReactTestUtils, Message} = require 'nylas-exports'

KeybaseSearch = require '../lib/keybase-search'

describe "KeybaseSearch", ->
  it "should have a displayName", ->
    expect(KeybaseSearch.displayName).toBe('KeybaseSearch')

  it "should have no results when rendered", ->
    @component = ReactTestUtils.renderIntoDocument(
      <KeybaseSearch />
    )

    expect(@component.state.results).toEqual([])

# behold, the most comprehensive test suite of all time

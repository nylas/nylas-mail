{React, ReactTestUtils, Message} = require 'nylas-exports'

KeybaseUser = require '../lib/keybase-user'

describe "KeybaseUserProfile", ->
  it "should have a displayName", ->
    expect(KeybaseUser.displayName).toBe('KeybaseUserProfile')

# behold, the most comprehensive test suite of all time

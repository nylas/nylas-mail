moment = require 'moment'
React = require "react"
ReactDOM = require "react-dom"
ReactTestUtils = require 'react-addons-test-utils'
MessageTimestamp = require('../lib/message-timestamp').default

msgTime = ->
  moment([2010, 1, 14, 15, 25, 50, 125]) # Feb 14, 2010 at 3:25 PM

describe "MessageTimestamp", ->
  beforeEach ->
    @item = ReactTestUtils.renderIntoDocument(
      <MessageTimestamp date={msgTime()} />
    )

  it "still processes one day, even if it crosses a month divider", ->
    # this should be tested in moment.js, but we add a test here for our own sanity too
    feb28 = moment([2015, 1, 28])
    mar01 = moment([2015, 2, 1])
    expect(mar01.diff(feb28, 'days')).toBe 1

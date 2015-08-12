moment = require 'moment'
React = require 'react/addons'
TestUtils = React.addons.TestUtils
MessageTimestamp = require '../lib/message-timestamp'

msgTime = ->
  moment([2010, 1, 14, 15, 25, 50, 125]) # Feb 14, 2010 at 3:25pm

describe "MessageTimestamp", ->
  beforeEach ->
    @item = TestUtils.renderIntoDocument(
      <MessageTimestamp date={msgTime()} />
    )

  it "still processes one day, even if it crosses a month divider", ->
    # this should be tested in moment.js, but we add a test here for our own sanity too
    feb28 = moment([2015, 1, 28])
    mar01 = moment([2015, 2, 1])
    expect(mar01.diff(feb28, 'days')).toBe 1

  it "displays the full time when in detailed timestamp mode", ->
    expect(@item._formattedDate(msgTime(), null, true)).toBe "February 14, 2010 at 3:25 PM"

  it "displays the time from messages shown today", ->
    now = msgTime().add(2, 'hours')
    expect(@item._formattedDate(msgTime(), now)).toBe "3:25 pm"

  it "displays the time from messages yesterday with the relative time if it's less than 36 hours ago", ->
    now = msgTime().add(21, 'hours')
    expect(@item._formattedDate(msgTime(), now)).toBe "3:25 pm (21 hours ago)"

    now = msgTime().add(30, 'hours')
    expect(@item._formattedDate(msgTime(), now)).toBe "3:25 pm (a day ago)"

  it "displays month, day for messages less than a year ago, but more than 24 hours ago", ->
    now = msgTime().add(2, 'months')
    expect(@item._formattedDate(msgTime(), now)).toBe "Feb 14"

  it "displays month, day, and year for messages over a year ago", ->
    now = msgTime().add(2, 'years')
    expect(@item._formattedDate(msgTime(), now)).toBe "Feb 14, 2010"
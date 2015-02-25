moment = require 'moment'
React = require 'react/addons'
TestUtils = React.addons.TestUtils
MessageTimestamp = require '../lib/message-timestamp.cjsx'

testDate = ->
  moment([2010, 1, 14, 15, 25, 50, 125])

describe "MessageTimestamp", ->
  beforeEach ->
    @item = TestUtils.renderIntoDocument(
      <MessageTimestamp date={testDate()} />
    )
    @itemNode = @item.getDOMNode()
  
  # test messsage time is 1415814587
  it "displays the time from messages LONG ago", ->
    spyOn(@item, "_today").andCallFake -> testDate().add(2, 'years')
    expect(@item._timeFormat()).toBe "MMM D YYYY"

  it "displays the time and date from messages a bit ago", ->
    spyOn(@item, "_today").andCallFake -> testDate().add(2, 'days')
    expect(@item._timeFormat()).toBe "MMM D, h:mm a"

  it "displays the time and date messages exactly a day ago", ->
    spyOn(@item, "_today").andCallFake -> testDate().add(1, 'day')
    expect(@item._timeFormat()).toBe "MMM D, h:mm a"

  it "displays the time from messages yesterday with the day, even though it's less than 24 hours ago", ->
    spyOn(@item, "_today").andCallFake -> moment([2010, 1, 15, 2, 25, 50, 125])
    expect(@item._timeFormat()).toBe "MMM D, h:mm a"

  it "displays the time from messages recently", ->
    spyOn(@item, "_today").andCallFake -> testDate().add(2, 'hours')
    expect(@item._timeFormat()).toBe "h:mm a"

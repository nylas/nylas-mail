TrackingPixelsExtension = require '../lib/plugins/tracking-pixels-extension'
{Message} = require 'nylas-exports'

testBody = """
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"><p>Hey Ben,</p><p>
I've noticed that we don't yet have an SLA in place with&nbsp;Nylas. Are you the right
person to be speaking with to make sure everything is set up on that end? If not,
could you please put me in touch with them, so that we can get you guys set up
correctly as soon as possible?</p><p>Thanks!</p><p>Gleb Polyakov</p><p>Head of
Business Development and Growth</p><img src="https://sdr.salesloft.com/email_trackers/8c8bea88-af43-4f66-bf78-a97ad73d7aec/open.gif" alt="" width="1" height="1">After Pixel
"""
testBodyProcessed = """
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"><p>Hey Ben,</p><p>
I've noticed that we don't yet have an SLA in place with&nbsp;Nylas. Are you the right
person to be speaking with to make sure everything is set up on that end? If not,
could you please put me in touch with them, so that we can get you guys set up
correctly as soon as possible?</p><p>Thanks!</p><p>Gleb Polyakov</p><p>Head of
Business Development and Growth</p>After Pixel
"""

describe "TrackingPixelsExtension", ->
  it "should splice tracking pixels and only run on messages by the current user", ->
    message = new Message(body: testBody)
    spyOn(message, 'isFromMe').andCallFake -> false
    TrackingPixelsExtension.formatMessageBody(message)
    expect(message.body).toEqual(testBody)

    message = new Message(body: testBody)
    spyOn(message, 'isFromMe').andCallFake -> true
    TrackingPixelsExtension.formatMessageBody(message)
    expect(message.body).toEqual(testBodyProcessed)

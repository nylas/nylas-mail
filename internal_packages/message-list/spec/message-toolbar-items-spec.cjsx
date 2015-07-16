React = require "react/addons"
TestUtils = React.addons.TestUtils
{Thread, FocusedContentStore, Actions} = require "nylas-exports"


MessageToolbarItems = require '../lib/message-toolbar-items'

test_thread = (new Thread).fromJSON({
  "id" : "thread_12345"
  "subject" : "Subject 12345"
  "starred": false
})

test_thread_starred = (new Thread).fromJSON({
  "id" : "thread_starred_12345"
  "subject" : "Subject 12345"
  "starred": true
})

describe "MessageToolbarItem starring", ->
  it "stars a thread if the star button is clicked and thread is unstarred", ->
    spyOn(FocusedContentStore, "focused").andCallFake ->
      test_thread
    spyOn(Actions, 'queueTask')
    messageToolbarItems = TestUtils.renderIntoDocument(<MessageToolbarItems />)

    starButton = React.findDOMNode(messageToolbarItems.refs.starButton)
    TestUtils.Simulate.click starButton

    expect(Actions.queueTask.mostRecentCall.args[0].objects).toEqual([test_thread])
    expect(Actions.queueTask.mostRecentCall.args[0].newValues).toEqual(starred: true)

  it "unstars a thread if the star button is clicked and thread is starred", ->
    spyOn(FocusedContentStore, "focused").andCallFake ->
      test_thread_starred
    spyOn(Actions, 'queueTask')
    messageToolbarItems = TestUtils.renderIntoDocument(<MessageToolbarItems />)

    starButton = React.findDOMNode(messageToolbarItems.refs.starButton)
    TestUtils.Simulate.click starButton

    expect(Actions.queueTask.mostRecentCall.args[0].objects).toEqual([test_thread_starred])
    expect(Actions.queueTask.mostRecentCall.args[0].newValues).toEqual(starred: false)

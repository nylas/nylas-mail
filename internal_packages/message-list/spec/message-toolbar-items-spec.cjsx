React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
TestUtils = React.addons.TestUtils
{Thread, FocusedContentStore, Actions} = require "nylas-exports"

StarButton = require '../lib/thread-star-button'

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
    spyOn(Actions, 'queueTask')
    starButton = TestUtils.renderIntoDocument(<StarButton thread={test_thread}/>)

    TestUtils.Simulate.click React.findDOMNode(starButton)

    expect(Actions.queueTask.mostRecentCall.args[0].objects).toEqual([test_thread])
    expect(Actions.queueTask.mostRecentCall.args[0].newValues).toEqual(starred: true)

  it "unstars a thread if the star button is clicked and thread is starred", ->
    spyOn(Actions, 'queueTask')
    starButton = TestUtils.renderIntoDocument(<StarButton thread={test_thread_starred}/>)

    TestUtils.Simulate.click React.findDOMNode(starButton)

    expect(Actions.queueTask.mostRecentCall.args[0].objects).toEqual([test_thread_starred])
    expect(Actions.queueTask.mostRecentCall.args[0].newValues).toEqual(starred: false)

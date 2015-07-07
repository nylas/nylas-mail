React = require "react/addons"
TestUtils = React.addons.TestUtils
{Thread, FocusedContentStore, Actions, AddRemoveTagsTask} = require "nylas-exports"


MessageToolbarItems = require '../lib/message-toolbar-items'

test_thread = (new Thread).fromJSON({
  "id" : "thread_12345"
  "subject" : "Subject 12345"
})

test_thread_starred = (new Thread).fromJSON({
  "id" : "thread_starred_12345"
  "subject" : "Subject 12345"
  "tags": [{"id": "starred"}]
})

describe "MessageToolbarItem starring", ->
  it "stars a thread if the star button is clicked and thread is unstarred", ->
    spyOn(FocusedContentStore, "focused").andCallFake ->
      test_thread
    spyOn(Actions, 'queueTask')
    messageToolbarItems = TestUtils.renderIntoDocument(<MessageToolbarItems />)

    starButton = React.findDOMNode(messageToolbarItems.refs.starButton)
    TestUtils.Simulate.click starButton

    expect(Actions.queueTask.mostRecentCall.args[0].threadsOrIds).toEqual([test_thread])
    expect(Actions.queueTask.mostRecentCall.args[0].tagIdsToAdd).toEqual(['starred'])
    expect(Actions.queueTask.mostRecentCall.args[0].tagIdsToRemove).toEqual([])

  it "unstars a thread if the star button is clicked and thread is starred", ->
    spyOn(FocusedContentStore, "focused").andCallFake ->
      test_thread_starred
    spyOn(Actions, 'queueTask')
    messageToolbarItems = TestUtils.renderIntoDocument(<MessageToolbarItems />)

    starButton = React.findDOMNode(messageToolbarItems.refs.starButton)
    TestUtils.Simulate.click starButton

    expect(Actions.queueTask.mostRecentCall.args[0].threadsOrIds).toEqual([test_thread_starred])
    expect(Actions.queueTask.mostRecentCall.args[0].tagIdsToAdd).toEqual([])
    expect(Actions.queueTask.mostRecentCall.args[0].tagIdsToRemove).toEqual(['starred'])

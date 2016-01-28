React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
TestUtils = React.addons.TestUtils
{Thread, FocusedContentStore, Actions, ChangeUnreadTask} = require "nylas-exports"

StarButton = require '../lib/thread-star-button'
ThreadToggleUnreadButton = require '../lib/thread-toggle-unread-button'

test_thread = (new Thread).fromJSON({
  "id" : "thread_12345"
  "account_id": TEST_ACCOUNT_ID
  "subject" : "Subject 12345"
  "starred": false
})

test_thread_starred = (new Thread).fromJSON({
  "id" : "thread_starred_12345"
  "account_id": TEST_ACCOUNT_ID
  "subject" : "Subject 12345"
  "starred": true
})

describe "MessageToolbarItem starring", ->
  it "stars a thread if the star button is clicked and thread is unstarred", ->
    spyOn(Actions, 'queueTask')
    starButton = TestUtils.renderIntoDocument(<StarButton thread={test_thread}/>)

    TestUtils.Simulate.click React.findDOMNode(starButton)

    expect(Actions.queueTask.mostRecentCall.args[0].threads).toEqual([test_thread])
    expect(Actions.queueTask.mostRecentCall.args[0].starred).toEqual(true)

  it "unstars a thread if the star button is clicked and thread is starred", ->
    spyOn(Actions, 'queueTask')
    starButton = TestUtils.renderIntoDocument(<StarButton thread={test_thread_starred}/>)

    TestUtils.Simulate.click React.findDOMNode(starButton)

    expect(Actions.queueTask.mostRecentCall.args[0].threads).toEqual([test_thread_starred])
    expect(Actions.queueTask.mostRecentCall.args[0].starred).toEqual(false)

describe "MessageToolbarItem marking as unread", ->
  thread = null
  markUnreadBtn = null

  beforeEach ->
    thread = new Thread(id: "thread-id-lol-123", accountId: TEST_ACCOUNT_ID)
    markUnreadBtn = ReactTestUtils.renderIntoDocument(
      <ThreadToggleUnreadButton thread={thread} />
    )

  it "queues a task to change unread status to true", ->
    spyOn Actions, "queueTask"
    ReactTestUtils.Simulate.click React.findDOMNode(markUnreadBtn).childNodes[0]

    changeUnreadTask = Actions.queueTask.calls[0].args[0]
    expect(changeUnreadTask instanceof ChangeUnreadTask).toBe true
    expect(changeUnreadTask.unread).toBe true
    expect(changeUnreadTask.threads[0].id).toBe thread.id

  it "returns to the thread list", ->
    spyOn Actions, "popSheet"
    ReactTestUtils.Simulate.click React.findDOMNode(markUnreadBtn).childNodes[0]

    expect(Actions.popSheet).toHaveBeenCalled()

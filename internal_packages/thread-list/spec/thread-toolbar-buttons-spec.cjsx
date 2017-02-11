React = require "react"
ReactDOM = require "react-dom"
ReactTestUtils = require 'react-addons-test-utils'
{
  Thread,
  FocusedContentStore,
  Actions,
  CategoryStore,
  ChangeUnreadTask,
  TaskFactory,
  MailboxPerspective
} = require "nylas-exports"
{ToggleStarredButton, ToggleUnreadButton, MarkAsSpamButton} = require '../lib/thread-toolbar-buttons'

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

describe "ThreadToolbarButtons", ->
  beforeEach ->
    spyOn Actions, "queueTask"
    spyOn Actions, "queueTasks"

  describe "Starring", ->
    it "stars a thread if the star button is clicked and thread is unstarred", ->
      starButton = ReactTestUtils.renderIntoDocument(<ToggleStarredButton items={[test_thread]}/>)

      ReactTestUtils.Simulate.click ReactDOM.findDOMNode(starButton)

      expect(Actions.queueTask.mostRecentCall.args[0].threads).toEqual([test_thread])
      expect(Actions.queueTask.mostRecentCall.args[0].starred).toEqual(true)

    it "unstars a thread if the star button is clicked and thread is starred", ->
      starButton = ReactTestUtils.renderIntoDocument(<ToggleStarredButton items={[test_thread_starred]}/>)

      ReactTestUtils.Simulate.click ReactDOM.findDOMNode(starButton)

      expect(Actions.queueTask.mostRecentCall.args[0].threads).toEqual([test_thread_starred])
      expect(Actions.queueTask.mostRecentCall.args[0].starred).toEqual(false)

  describe "Marking as unread", ->
    thread = null
    markUnreadBtn = null

    beforeEach ->
      thread = new Thread(id: "thread-id-lol-123", accountId: TEST_ACCOUNT_ID, unread: false)
      markUnreadBtn = ReactTestUtils.renderIntoDocument(
        <ToggleUnreadButton items={[thread]} />
      )

    it "queues a task to change unread status to true", ->
      ReactTestUtils.Simulate.click ReactDOM.findDOMNode(markUnreadBtn).childNodes[0]

      changeUnreadTask = Actions.queueTask.calls[0].args[0]
      expect(changeUnreadTask instanceof ChangeUnreadTask).toBe true
      expect(changeUnreadTask.unread).toBe true
      expect(changeUnreadTask.threads[0].id).toBe thread.id

    it "returns to the thread list", ->
      spyOn Actions, "popSheet"
      ReactTestUtils.Simulate.click ReactDOM.findDOMNode(markUnreadBtn).childNodes[0]

      expect(Actions.popSheet).toHaveBeenCalled()

  describe "Marking as spam", ->
    thread = null
    markSpamButton = null

    describe "when the thread is already in spam", ->
      beforeEach ->
        thread = new Thread({
          id: "thread-id-lol-123",
          accountId: TEST_ACCOUNT_ID,
          categories: [{name: 'spam'}]
        })
        markSpamButton = ReactTestUtils.renderIntoDocument(
          <MarkAsSpamButton items={[thread]} />
        )

      it "queues a task to remove spam", ->
        spyOn(CategoryStore, 'getSpamCategory').andReturn(thread.categories[0])
        ReactTestUtils.Simulate.click(ReactDOM.findDOMNode(markSpamButton))
        {labelsToAdd, labelsToRemove} = Actions.queueTasks.mostRecentCall.args[0][0]
        expect(labelsToAdd).toEqual([])
        expect(labelsToRemove).toEqual([thread.categories[0]])

    describe "when the thread can be moved to spam", ->
      beforeEach ->
        spyOn(MailboxPerspective.prototype, 'canMoveThreadsTo').andReturn(true)
        thread = new Thread(id: "thread-id-lol-123", accountId: TEST_ACCOUNT_ID, categories: [])
        markSpamButton = ReactTestUtils.renderIntoDocument(
          <MarkAsSpamButton items={[thread]} />
        )

      it "queues a task to mark as spam", ->
        spyOn(TaskFactory, 'tasksForMarkingAsSpam')
        ReactTestUtils.Simulate.click(ReactDOM.findDOMNode(markSpamButton))
        expect(TaskFactory.tasksForMarkingAsSpam).toHaveBeenCalledWith({
          threads: [thread],
          source: 'Toolbar Button: Thread List'
        })

      it "returns to the thread list", ->
        spyOn(Actions, 'popSheet')
        ReactTestUtils.Simulate.click(ReactDOM.findDOMNode(markSpamButton))
        expect(Actions.popSheet).toHaveBeenCalled()

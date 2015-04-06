_ = require 'underscore-plus'
Thread = require '../../src/flux/models/thread'
FocusedThreadStore = require '../../src/flux/stores/focused-thread-store'
MarkThreadReadTask = require '../../src/flux/tasks/mark-thread-read'
Actions = require '../../src/flux/actions'

testThread = new Thread(id: '123')

describe "FocusedThreadStore", ->
  describe "onFocusThread", ->
    it "should not trigger if the thread is already focused", ->
      FocusedThreadStore._onFocusThread(testThread)
      spyOn(FocusedThreadStore, 'trigger')
      FocusedThreadStore._onFocusThread(testThread)
      expect(FocusedThreadStore.trigger).not.toHaveBeenCalled()

    it "should not trigger if the focus is already null", ->
      FocusedThreadStore._onFocusThread(null)
      spyOn(FocusedThreadStore, 'trigger')
      FocusedThreadStore._onFocusThread(null)
      expect(FocusedThreadStore.trigger).not.toHaveBeenCalled()

    it "should trigger otherwise", ->
      FocusedThreadStore._onFocusThread(null)
      spyOn(FocusedThreadStore, 'trigger')
      FocusedThreadStore._onFocusThread(testThread)
      expect(FocusedThreadStore.trigger).toHaveBeenCalled()

    describe "when the thread is unread", ->
      beforeEach ->
        FocusedThreadStore._onFocusThread(null)
        spyOn(testThread, 'isUnread').andCallFake -> true

      it "should queue a task to mark the thread as read", ->
        spyOn(Actions, 'queueTask')
        FocusedThreadStore._onFocusThread(testThread)
        expect(Actions.queueTask).toHaveBeenCalled()
        expect(Actions.queueTask.mostRecentCall.args[0] instanceof MarkThreadReadTask).toBe(true)

  describe "threadId", ->
    it "should return the id of the focused thread", ->
      FocusedThreadStore._onFocusThread(testThread)
      expect(FocusedThreadStore.threadId()).toBe(testThread.id)

  describe "thread", ->
    it "should return the focused thread object", ->
      FocusedThreadStore._onFocusThread(testThread)
      expect(FocusedThreadStore.thread()).toBe(testThread)

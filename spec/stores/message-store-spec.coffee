_ = require 'underscore'
Thread = require '../../src/flux/models/thread'
Message = require '../../src/flux/models/message'
FocusedContentStore = require '../../src/flux/stores/focused-content-store'
MessageStore = require '../../src/flux/stores/message-store'
DatabaseStore = require '../../src/flux/stores/database-store'
ChangeUnreadTask = require '../../src/flux/tasks/change-unread-task'
Actions = require '../../src/flux/actions'

testThread = new Thread(id: '123', accountId: TEST_ACCOUNT_ID)
testMessage1 = new Message(id: 'a', body: '123', files: [], accountId: TEST_ACCOUNT_ID)
testMessage2 = new Message(id: 'b', body: '123', files: [], accountId: TEST_ACCOUNT_ID)
testMessage3 = new Message(id: 'c', body: '123', files: [], accountId: TEST_ACCOUNT_ID)

describe "MessageStore", ->
  describe "when the receiving focus changes from the FocusedContentStore", ->
    beforeEach ->
      if MessageStore._onFocusChangedTimer
        clearTimeout(MessageStore._onFocusChangedTimer)
        MessageStore._onFocusChangedTimer = null
      spyOn(MessageStore, '_onApplyFocusChange')

    afterEach ->
      if MessageStore._onFocusChangedTimer
        clearTimeout(MessageStore._onFocusChangedTimer)
        MessageStore._onFocusChangedTimer = null

    describe "if no change has happened in the last 100ms", ->
      it "should apply immediately", ->
        FocusedContentStore.trigger(impactsCollection: (c) -> true )
        expect(MessageStore._onApplyFocusChange).toHaveBeenCalled()

    describe "if a change has happened in the last 100ms", ->
      it "should not apply immediately", ->
        noop = =>
        MessageStore._onFocusChangedTimer = setTimeout(noop, 100)
        FocusedContentStore.trigger(impactsCollection: (c) -> true )
        expect(MessageStore._onApplyFocusChange).not.toHaveBeenCalled()

      it "should apply 100ms after the last focus change and reset", ->
        FocusedContentStore.trigger(impactsCollection: (c) -> true )
        expect(MessageStore._onApplyFocusChange.callCount).toBe(1)
        advanceClock(50)
        FocusedContentStore.trigger(impactsCollection: (c) -> true )
        expect(MessageStore._onApplyFocusChange.callCount).toBe(1)
        advanceClock(50)
        FocusedContentStore.trigger(impactsCollection: (c) -> true )
        expect(MessageStore._onApplyFocusChange.callCount).toBe(1)
        advanceClock(150)
        FocusedContentStore.trigger(impactsCollection: (c) -> true )
        expect(MessageStore._onApplyFocusChange.callCount).toBe(3)
        advanceClock(150)
        FocusedContentStore.trigger(impactsCollection: (c) -> true )
        expect(MessageStore._onApplyFocusChange.callCount).toBe(5)

  describe "when applying focus changes", ->
    beforeEach ->
      MessageStore._lastLoadedThreadId = null

      @focus = null
      spyOn(FocusedContentStore, 'focused').andCallFake (collection) =>
        if collection is 'thread'
          @focus
        else
          null

      spyOn(FocusedContentStore, 'focusedId').andCallFake (collection) =>
        if collection is 'thread'
          @focus?.id
        else
          null

      spyOn(DatabaseStore, 'findAll').andCallFake ->
        include: -> @
        where: -> @
        then: (callback) -> callback([testMessage1, testMessage2])

    it "should retrieve the focused thread", ->
      @focus = testThread
      MessageStore._thread = null
      MessageStore._onApplyFocusChange()
      expect(DatabaseStore.findAll).toHaveBeenCalled()
      expect(DatabaseStore.findAll.mostRecentCall.args[0]).toBe(Message)

    describe "when the thread is already focused", ->
      it "should do nothing", ->
        @focus = testThread
        MessageStore._thread = @focus
        MessageStore._onApplyFocusChange()
        expect(DatabaseStore.findAll).not.toHaveBeenCalled()

    describe "when the thread is unread", ->
      beforeEach ->
        @focus = null
        MessageStore._onApplyFocusChange()
        testThread.unread = true
        spyOn(Actions, 'queueTask')
        spyOn(NylasEnv.config, 'get').andCallFake (key) =>
          if key is 'core.reading.markAsReadDelay'
            return 600

      it "should queue a task to mark the thread as read", ->
        @focus = testThread
        MessageStore._onApplyFocusChange()
        advanceClock(500)
        expect(Actions.queueTask).not.toHaveBeenCalled()
        advanceClock(500)
        expect(Actions.queueTask).toHaveBeenCalled()
        expect(Actions.queueTask.mostRecentCall.args[0] instanceof ChangeUnreadTask).toBe(true)

      it "should not queue a task to mark the thread as read if the thread is no longer selected 500msec later", ->
        @focus = testThread
        MessageStore._onApplyFocusChange()
        advanceClock(500)
        expect(Actions.queueTask).not.toHaveBeenCalled()
        @focus = null
        MessageStore._onApplyFocusChange()
        advanceClock(500)
        expect(Actions.queueTask).not.toHaveBeenCalled()

      it "should not re-mark the thread as read when made unread", ->
        @focus = testThread
        testThread.unread = false
        MessageStore._onApplyFocusChange()
        advanceClock(500)
        expect(Actions.queueTask).not.toHaveBeenCalled()

        # This simulates a DB change or some attribute changing on the
        # thread.
        testThread.unread = true
        MessageStore._fetchFromCache()
        advanceClock(500)
        expect(Actions.queueTask).not.toHaveBeenCalled()

  describe "when toggling expansion of all messages", ->
    beforeEach ->
      MessageStore._items = [testMessage1, testMessage2, testMessage3]
      spyOn(MessageStore, '_fetchExpandedAttachments')

    it 'should expand all when at default state', ->
      MessageStore._itemsExpanded = {c: 'default'}
      Actions.toggleAllMessagesExpanded()
      expect(MessageStore._itemsExpanded).toEqual a: 'explicit', b: 'explicit', c: 'explicit'

    it 'should expand all when at least one item is collapsed', ->
      MessageStore._itemsExpanded = {b: 'explicit', c: 'explicit'}
      Actions.toggleAllMessagesExpanded()
      expect(MessageStore._itemsExpanded).toEqual a: 'explicit', b: 'explicit', c: 'explicit'

    it 'should collapse all except the latest message when all expanded', ->
      MessageStore._itemsExpanded = {a: 'explicit', b: 'explicit', c: 'explicit'}
      Actions.toggleAllMessagesExpanded()
      expect(MessageStore._itemsExpanded).toEqual c: 'explicit'

_ = require 'underscore'
Thread = require '../../src/flux/models/thread'
FocusedContentStore = require '../../src/flux/stores/focused-content-store'
Actions = require '../../src/flux/actions'

testThread = new Thread(id: '123', accountId: TEST_ACCOUNT_ID)

describe "FocusedContentStore", ->
  describe "onSetFocus", ->
    it "should not trigger if the thread is already focused", ->
      FocusedContentStore._onFocus({collection: 'thread', item: testThread})
      spyOn(FocusedContentStore, 'triggerAfterAnimationFrame')
      FocusedContentStore._onFocus({collection: 'thread', item: testThread})
      expect(FocusedContentStore.triggerAfterAnimationFrame).not.toHaveBeenCalled()

    it "should not trigger if the focus is already null", ->
      FocusedContentStore._onFocus({collection: 'thread', item: null})
      spyOn(FocusedContentStore, 'triggerAfterAnimationFrame')
      FocusedContentStore._onFocus({collection: 'thread', item: null})
      expect(FocusedContentStore.triggerAfterAnimationFrame).not.toHaveBeenCalled()

    it "should trigger otherwise", ->
      FocusedContentStore._onFocus({collection: 'thread', item: null})
      spyOn(FocusedContentStore, 'triggerAfterAnimationFrame')
      FocusedContentStore._onFocus({collection: 'thread', item: testThread})
      expect(FocusedContentStore.triggerAfterAnimationFrame).toHaveBeenCalled()

  describe "threadId", ->
    it "should return the id of the focused thread", ->
      FocusedContentStore._onFocus({collection: 'thread', item: testThread})
      expect(FocusedContentStore.focusedId('thread')).toBe(testThread.id)

  describe "thread", ->
    it "should return the focused thread object", ->
      FocusedContentStore._onFocus({collection: 'thread', item: testThread})
      expect(FocusedContentStore.focused('thread')).toBe(testThread)

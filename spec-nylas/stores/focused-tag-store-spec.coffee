_ = require 'underscore'
Tag = require '../../src/flux/models/tag'
NamespaceStore = require '../../src/flux/stores/namespace-store'
FocusedTagStore = require '../../src/flux/stores/focused-tag-store'
Actions = require '../../src/flux/actions'

initialTag = new Tag(id: 'initial', name: 'Initial')
otherTag = new Tag(id: 'bowling', name: 'Bowling')

describe "FocusedTagStore", ->
  beforeEach ->
    FocusedTagStore._onFocusTag(initialTag)
    spyOn(FocusedTagStore, 'trigger')

  describe "when the namespace changes", ->
    it "should change the focused tag to Inbox and trigger", ->
      NamespaceStore.trigger()
      expect(FocusedTagStore.trigger).toHaveBeenCalled()
      expect(FocusedTagStore.tagId()).toBe('inbox')

  describe "when a search query is committed", ->
    it "should clear the focused tag and trigger", ->
      FocusedTagStore._onSearchQueryCommitted('bla')
      expect(FocusedTagStore.trigger).toHaveBeenCalled()
      expect(FocusedTagStore.tag()).toBe(null)
      expect(FocusedTagStore.tagId()).toBe(null)

  describe "when a search query is cleared", ->
    it "should restore the tag that was previously focused and trigger", ->
      FocusedTagStore._onSearchQueryCommitted('bla')
      expect(FocusedTagStore.tag()).toBe(null)
      expect(FocusedTagStore.tagId()).toBe(null)
      FocusedTagStore._onSearchQueryCommitted('')
      expect(FocusedTagStore.trigger).toHaveBeenCalled()
      expect(FocusedTagStore.tag()).toBe(initialTag)
      expect(FocusedTagStore.tagId()).toBe(initialTag.id)

  describe "when Actions.focusTag is called", ->
    it "should focus the tag and trigger", ->
      FocusedTagStore._onFocusTag(otherTag)
      expect(FocusedTagStore.trigger).toHaveBeenCalled()
      expect(FocusedTagStore.tagId()).toBe(otherTag.id)
      expect(FocusedTagStore.tag()).toBe(otherTag)

    it "should do nothing if the tag is already focused", ->
      FocusedTagStore._onFocusTag(initialTag)
      expect(FocusedTagStore.trigger).not.toHaveBeenCalled()


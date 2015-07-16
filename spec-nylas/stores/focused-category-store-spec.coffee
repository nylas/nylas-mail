_ = require 'underscore'

Label = require '../../src/flux/models/label'
Folder = require '../../src/flux/models/folder'

CategoryStore = require '../../src/flux/stores/category-store'
NamespaceStore = require '../../src/flux/stores/namespace-store'
FocusedCategoryStore = require '../../src/flux/stores/focused-category-store'

describe "FocusedCategoryStore", ->
  beforeEach ->
    spyOn(FocusedCategoryStore, 'trigger')
    FocusedCategoryStore._category = null

  afterEach ->
    atom.testOrganizationUnit = null

  testStore = ->
    it "should change the focused category to Inbox and trigger when the namespace changes", ->
      FocusedCategoryStore._onFocusCategory(@userCategory)
      FocusedCategoryStore._setDefaultCategory()
      expect(FocusedCategoryStore.trigger).toHaveBeenCalled()
      expect(FocusedCategoryStore.categoryName()).toBe('inbox')

    it "should clear the focused category and trigger when a search query is committed", ->
      FocusedCategoryStore._onSearchQueryCommitted('bla')
      expect(FocusedCategoryStore.trigger).toHaveBeenCalled()
      expect(FocusedCategoryStore.category()).toBe(null)
      expect(FocusedCategoryStore.categoryName()).toBe(null)

    it "should restore the category that was previously focused and trigger when a search query is cleared", ->
      FocusedCategoryStore._onFocusCategory(@userCategory)
      FocusedCategoryStore._onSearchQueryCommitted('bla')
      expect(FocusedCategoryStore.category()).toEqual(null)
      expect(FocusedCategoryStore.categoryName()).toEqual(null)
      FocusedCategoryStore._onSearchQueryCommitted('')
      expect(FocusedCategoryStore.trigger).toHaveBeenCalled()
      expect(FocusedCategoryStore.category().id).toEqual(@userCategory.id)
      expect(FocusedCategoryStore.categoryName()).toEqual(null)

    it "should focus the category and trigger when Actions.focusCategory is called", ->
      FocusedCategoryStore._onFocusCategory(@userCategory)
      expect(FocusedCategoryStore.trigger).toHaveBeenCalled()
      expect(FocusedCategoryStore.categoryName()).toBe(null)
      expect(FocusedCategoryStore.category()).toEqual(@userCategory)

    it "should do nothing if the category is already focused", ->
      FocusedCategoryStore._onFocusCategory(@inboxCategory)
      spyOn(FocusedCategoryStore, '_setCategory')
      expect(FocusedCategoryStore._setCategory).not.toHaveBeenCalled()

  describe 'when using labels', ->
    beforeEach ->
      atom.testOrganizationUnit = 'label'

      @inboxCategory = new Label(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @userCategory = new Label(id: 'id-456', name: null, displayName: "MyCategory")

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory
      FocusedCategoryStore._setDefaultCategory()

    testStore()

  describe 'when using folders', ->
    beforeEach ->
      atom.testOrganizationUnit = 'folder'

      @inboxCategory = new Folder(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @userCategory = new Folder(id: 'id-456', name: null, displayName: "MyCategory")

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory
      FocusedCategoryStore._setDefaultCategory()

    testStore()


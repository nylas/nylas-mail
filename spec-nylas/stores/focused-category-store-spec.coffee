_ = require 'underscore'

Label = require '../../src/flux/models/label'
Folder = require '../../src/flux/models/folder'

CategoryStore = require '../../src/flux/stores/category-store'
AccountStore = require '../../src/flux/stores/account-store'
FocusedCategoryStore = require '../../src/flux/stores/focused-category-store'

describe "FocusedCategoryStore", ->
  beforeEach ->
    spyOn(FocusedCategoryStore, 'trigger')
    FocusedCategoryStore._category = null

  afterEach ->
    atom.testOrganizationUnit = null

  testStore = ->
    describe "_onCategoryStoreChanged", ->
      it "should set the current category to Inbox when it is unset", ->
        FocusedCategoryStore._category = null
        FocusedCategoryStore._onCategoryStoreChanged()
        expect(FocusedCategoryStore.category().id).toEqual(@inboxCategory.id)

      it "should set the current category to Inbox when the current category no longer exists in the CategoryStore", ->
        otherAccountInbox = @inboxCategory.clone()
        otherAccountInbox.id = 'other-id'
        FocusedCategoryStore._category = otherAccountInbox
        FocusedCategoryStore._onCategoryStoreChanged()
        expect(FocusedCategoryStore.category().id).toEqual(@inboxCategory.id)

    describe "_onSearchQueryCommitted", ->
      it "should clear the focused category and trigger when a search query is committed", ->
        FocusedCategoryStore._onFocusCategory(@userCategory)
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

    describe "_onFocusCategory", ->
      it "should focus the category and trigger when Actions.focusCategory is called", ->
        FocusedCategoryStore._onFocusCategory(@userCategory)
        expect(FocusedCategoryStore.trigger).toHaveBeenCalled()
        expect(FocusedCategoryStore.categoryName()).toBe(null)
        expect(FocusedCategoryStore.category().id).toEqual(@userCategory.id)

      it "should do nothing if the category is already focused", ->
        FocusedCategoryStore._onFocusCategory(@inboxCategory)
        spyOn(FocusedCategoryStore, '_setCategory')
        FocusedCategoryStore._onFocusCategory(@inboxCategory)
        expect(FocusedCategoryStore._setCategory).not.toHaveBeenCalled()

  describe 'when using labels', ->
    beforeEach ->
      atom.testOrganizationUnit = 'label'

      @inboxCategory = new Label(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @userCategory = new Label(id: 'id-456', name: null, displayName: "MyCategory")

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory
      spyOn(CategoryStore, "byId").andCallFake (id) =>
        return @inboxCategory if id is @inboxCategory.id
        return @userCategory if id is @userCategory.id
        return null

    testStore()

  describe 'when using folders', ->
    beforeEach ->
      atom.testOrganizationUnit = 'folder'

      @inboxCategory = new Folder(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @userCategory = new Folder(id: 'id-456', name: null, displayName: "MyCategory")

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory

    testStore()

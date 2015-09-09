_ = require 'underscore'

Actions = require '../../src/flux/actions'
Label = require '../../src/flux/models/label'
Folder = require '../../src/flux/models/folder'
MailViewFilter = require '../../src/mail-view-filter'

CategoryStore = require '../../src/flux/stores/category-store'
AccountStore = require '../../src/flux/stores/account-store'
FocusedMailViewStore = require '../../src/flux/stores/focused-mail-view-store'

describe "FocusedMailViewStore", ->
  beforeEach ->
    spyOn(FocusedMailViewStore, 'trigger')
    FocusedMailViewStore._mailView = null

  afterEach ->
    atom.testOrganizationUnit = null

  testStore = ->
    describe "_onCategoryStoreChanged", ->
      it "should set the current category to Inbox when it is unset", ->
        FocusedMailViewStore._mailView = null
        FocusedMailViewStore._onCategoryStoreChanged()
        expect(FocusedMailViewStore.mailView()).not.toBe(null)
        expect(FocusedMailViewStore.mailView().categoryId()).toEqual(@inboxCategory.id)

      it "should set the current category to Inbox when the current category no longer exists in the CategoryStore", ->
        otherAccountInbox = @inboxCategory.clone()
        otherAccountInbox.serverId = 'other-id'
        FocusedMailViewStore._mailView = MailViewFilter.forCategory(otherAccountInbox)
        FocusedMailViewStore._onCategoryStoreChanged()
        expect(FocusedMailViewStore.mailView().categoryId()).toEqual(@inboxCategory.id)

    describe "_onSearchQueryCommitted", ->
      it "should change to a search mail view when a search query is committed", ->
        FocusedMailViewStore._onFocusMailView(@userFilter)
        FocusedMailViewStore._onSearchQueryCommitted('bla')
        expect(FocusedMailViewStore.trigger).toHaveBeenCalled()
        expect(FocusedMailViewStore.mailView().isEqual(MailViewFilter.forSearch('bla'))).toBe(true)

      it "should restore the category that was previously focused and trigger when a search query is cleared", ->
        FocusedMailViewStore._onFocusMailView(@userFilter)
        FocusedMailViewStore._onSearchQueryCommitted('bla')
        expect(FocusedMailViewStore.mailView().isEqual(MailViewFilter.forSearch('bla'))).toBe(true)
        FocusedMailViewStore._onSearchQueryCommitted('')
        expect(FocusedMailViewStore.trigger).toHaveBeenCalled()
        expect(FocusedMailViewStore.mailView().categoryId()).toEqual(@userCategory.id)

    describe "_onFocusMailView", ->
      it "should focus the category and trigger when Actions.focusCategory is called", ->
        FocusedMailViewStore._onFocusMailView(@userFilter)
        expect(FocusedMailViewStore.trigger).toHaveBeenCalled()
        expect(FocusedMailViewStore.mailView().categoryId()).toEqual(@userCategory.id)

      it "should do nothing if the category is already focused", ->
        FocusedMailViewStore._onFocusMailView(@inboxFilter)
        spyOn(FocusedMailViewStore, '_setMailView')
        FocusedMailViewStore._onFocusMailView(@inboxFilter)
        expect(FocusedMailViewStore._setMailView).not.toHaveBeenCalled()

      it "should clear existing searches if any other category is focused", ->
        spyOn(Actions, 'searchQueryCommitted')
        FocusedMailViewStore._onSearchQueryCommitted('bla')
        FocusedMailViewStore._onFocusMailView(@userFilter)
        expect(Actions.searchQueryCommitted).toHaveBeenCalledWith('')

  describe 'when using labels', ->
    beforeEach ->
      atom.testOrganizationUnit = 'label'

      @inboxCategory = new Label(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @inboxFilter = MailViewFilter.forCategory(@inboxCategory)
      @userCategory = new Label(id: 'id-456', name: null, displayName: "MyCategory")
      @userFilter = MailViewFilter.forCategory(@userCategory)

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
      @inboxFilter = MailViewFilter.forCategory(@inboxCategory)
      @userCategory = new Folder(id: 'id-456', name: null, displayName: "MyCategory")
      @userFilter = MailViewFilter.forCategory(@userCategory)

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory

    testStore()

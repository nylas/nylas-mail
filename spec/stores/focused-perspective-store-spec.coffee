_ = require 'underscore'

Actions = require '../../src/flux/actions'
Label = require '../../src/flux/models/label'
Folder = require '../../src/flux/models/folder'
MailboxPerspective = require '../../src/mailbox-perspective'

CategoryStore = require '../../src/flux/stores/category-store'
AccountStore = require '../../src/flux/stores/account-store'
FocusedPerspectiveStore = require '../../src/flux/stores/focused-perspective-store'

describe "FocusedPerspectiveStore", ->
  beforeEach ->
    spyOn(FocusedPerspectiveStore, 'trigger')
    FocusedPerspectiveStore._perspective = null

  afterEach ->
    NylasEnv.testOrganizationUnit = null

  testStore = ->
    describe "_onCategoryStoreChanged", ->
      it "should set the current category to Inbox when it is unset", ->
        FocusedPerspectiveStore._perspective = null
        FocusedPerspectiveStore._onCategoryStoreChanged()
        expect(FocusedPerspectiveStore.current()).not.toBe(null)
        expect(FocusedPerspectiveStore.current().categoryId()).toEqual(@inboxCategory.id)

      it "should set the current category to Inbox when the current category no longer exists in the CategoryStore", ->
        otherAccountInbox = @inboxCategory.clone()
        otherAccountInbox.serverId = 'other-id'
        FocusedPerspectiveStore._perspective = MailboxPerspective.forCategory(otherAccountInbox)
        FocusedPerspectiveStore._onCategoryStoreChanged()
        expect(FocusedPerspectiveStore.current().categoryId()).toEqual(@inboxCategory.id)

    describe "_onSearchQueryCommitted", ->
      it "should change to a search mail view when a search query is committed", ->
        FocusedPerspectiveStore._onFocusMailView(@userFilter)
        FocusedPerspectiveStore._onSearchQueryCommitted('bla')
        expect(FocusedPerspectiveStore.trigger).toHaveBeenCalled()
        expect(FocusedPerspectiveStore.current().isEqual(MailboxPerspective.forSearch('bla'))).toBe(true)

      it "should restore the category that was previously focused and trigger when a search query is cleared", ->
        FocusedPerspectiveStore._onFocusMailView(@userFilter)
        FocusedPerspectiveStore._onSearchQueryCommitted('bla')
        expect(FocusedPerspectiveStore.current().isEqual(MailboxPerspective.forSearch('bla'))).toBe(true)
        FocusedPerspectiveStore._onSearchQueryCommitted('')
        expect(FocusedPerspectiveStore.trigger).toHaveBeenCalled()
        expect(FocusedPerspectiveStore.current().categoryId()).toEqual(@userCategory.id)

    describe "_onFocusMailView", ->
      it "should focus the category and trigger when Actions.focusCategory is called", ->
        FocusedPerspectiveStore._onFocusMailView(@userFilter)
        expect(FocusedPerspectiveStore.trigger).toHaveBeenCalled()
        expect(FocusedPerspectiveStore.current().categoryId()).toEqual(@userCategory.id)

      it "should do nothing if the category is already focused", ->
        FocusedPerspectiveStore._onFocusMailView(@inboxFilter)
        spyOn(FocusedPerspectiveStore, '_setMailView')
        FocusedPerspectiveStore._onFocusMailView(@inboxFilter)
        expect(FocusedPerspectiveStore._setMailView).not.toHaveBeenCalled()

      it "should clear existing searches if any other category is focused", ->
        spyOn(Actions, 'searchQueryCommitted')
        FocusedPerspectiveStore._onSearchQueryCommitted('bla')
        FocusedPerspectiveStore._onFocusMailView(@userFilter)
        expect(Actions.searchQueryCommitted).toHaveBeenCalledWith('')

  describe 'when using labels', ->
    beforeEach ->
      NylasEnv.testOrganizationUnit = 'label'

      @inboxCategory = new Label(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @inboxFilter = MailboxPerspective.forCategory(@inboxCategory)
      @userCategory = new Label(id: 'id-456', name: null, displayName: "MyCategory")
      @userFilter = MailboxPerspective.forCategory(@userCategory)

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory
      spyOn(CategoryStore, "byId").andCallFake (id) =>
        return @inboxCategory if id is @inboxCategory.id
        return @userCategory if id is @userCategory.id
        return null

    testStore()

  describe 'when using folders', ->
    beforeEach ->
      NylasEnv.testOrganizationUnit = 'folder'

      @inboxCategory = new Folder(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @inboxFilter = MailboxPerspective.forCategory(@inboxCategory)
      @userCategory = new Folder(id: 'id-456', name: null, displayName: "MyCategory")
      @userFilter = MailboxPerspective.forCategory(@userCategory)

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory

    testStore()

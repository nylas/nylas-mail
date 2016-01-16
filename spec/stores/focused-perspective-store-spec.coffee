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
    @account = AccountStore.accounts()[0]

  afterEach ->
    NylasEnv.testOrganizationUnit = null

  testStore = ->
    describe "_onCategoryStoreChanged", ->
      it "should set the current category to Inbox when it is unset", ->
        FocusedPerspectiveStore._perspective = null
        FocusedPerspectiveStore._onCategoryStoreChanged()
        expect(FocusedPerspectiveStore.current()).not.toBe(null)
        expect(FocusedPerspectiveStore.current().category().id).toEqual(@inboxCategory.id)

      it "should set the current category to Inbox when the current category no longer exists in the CategoryStore", ->
        otherAccountInbox = @inboxCategory.clone()
        otherAccountInbox.serverId = 'other-id'
        FocusedPerspectiveStore._perspective = MailboxPerspective.forCategory(@account, otherAccountInbox)
        FocusedPerspectiveStore._onCategoryStoreChanged()
        expect(FocusedPerspectiveStore.current().category().id).toEqual(@inboxCategory.id)

    describe "_onFocusPerspective", ->
      it "should focus the category and trigger when Actions.focusCategory is called", ->
        FocusedPerspectiveStore._onFocusPerspective(@userFilter)
        expect(FocusedPerspectiveStore.trigger).toHaveBeenCalled()
        expect(FocusedPerspectiveStore.current().category().id).toEqual(@userCategory.id)

      it "should do nothing if the category is already focused", ->
        FocusedPerspectiveStore._onFocusPerspective(@inboxFilter)
        spyOn(FocusedPerspectiveStore, '_setPerspective')
        FocusedPerspectiveStore._onFocusPerspective(@inboxFilter)
        expect(FocusedPerspectiveStore._setPerspective).not.toHaveBeenCalled()

  describe 'when using labels', ->
    beforeEach ->
      NylasEnv.testOrganizationUnit = 'label'

      @inboxCategory = new Label(id: 'id-123', name: 'inbox', displayName: "INBOX")
      @inboxFilter = MailboxPerspective.forCategory(@account, @inboxCategory)
      @userCategory = new Label(id: 'id-456', name: null, displayName: "MyCategory")
      @userFilter = MailboxPerspective.forCategory(@account, @userCategory)

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
      @inboxFilter = MailboxPerspective.forCategory(@account, @inboxCategory)
      @userCategory = new Folder(id: 'id-456', name: null, displayName: "MyCategory")
      @userFilter = MailboxPerspective.forCategory(@account, @userCategory)

      spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory

    testStore()

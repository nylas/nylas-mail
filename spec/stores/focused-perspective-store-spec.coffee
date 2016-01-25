_ = require 'underscore'

Actions = require '../../src/flux/actions'
Category = require '../../src/flux/models/category'
MailboxPerspective = require '../../src/mailbox-perspective'

CategoryStore = require '../../src/flux/stores/category-store'
AccountStore = require '../../src/flux/stores/account-store'
FocusedPerspectiveStore = require '../../src/flux/stores/focused-perspective-store'

describe "FocusedPerspectiveStore", ->
  beforeEach ->
    spyOn(FocusedPerspectiveStore, 'trigger')
    FocusedPerspectiveStore._perspective = null
    @account = AccountStore.accounts()[0]

    @inboxCategory = new Category(id: 'id-123', name: 'inbox', displayName: "INBOX", accountId: @account.id)
    @inboxFilter = MailboxPerspective.forCategory(@inboxCategory)
    @userCategory = new Category(id: 'id-456', name: null, displayName: "MyCategory", accountId: @account.id)
    @userFilter = MailboxPerspective.forCategory(@userCategory)

    spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory
    spyOn(CategoryStore, "byId").andCallFake (id) =>
      return @inboxCategory if id is @inboxCategory.id
      return @userCategory if id is @userCategory.id
      return null

  describe "_onCategoryStoreChanged", ->
    it "should set the current category to Inbox when it is unset", ->
      FocusedPerspectiveStore._perspective = null
      FocusedPerspectiveStore._onCategoryStoreChanged()
      expect(FocusedPerspectiveStore.current()).not.toBe(null)
      expect(FocusedPerspectiveStore.current().categories()).toEqual([@inboxCategory])

    it "should set the current category to Inbox when the current category no longer exists in the CategoryStore", ->
      otherAccountInbox = @inboxCategory.clone()
      otherAccountInbox.serverId = 'other-id'
      FocusedPerspectiveStore._perspective = MailboxPerspective.forCategory(otherAccountInbox)
      FocusedPerspectiveStore._onCategoryStoreChanged()
      expect(FocusedPerspectiveStore.current().categories()).toEqual([@inboxCategory])

  describe "_onFocusPerspective", ->
    it "should focus the category and trigger when Actions.focusCategory is called", ->
      FocusedPerspectiveStore._onFocusPerspective(@userFilter)
      expect(FocusedPerspectiveStore.trigger).toHaveBeenCalled()
      expect(FocusedPerspectiveStore.current().categories()).toEqual([@userCategory])

    it "should do nothing if the category is already focused", ->
      FocusedPerspectiveStore._onFocusPerspective(@inboxFilter)
      spyOn(FocusedPerspectiveStore, '_setPerspective')
      FocusedPerspectiveStore._onFocusPerspective(@inboxFilter)
      expect(FocusedPerspectiveStore._setPerspective).not.toHaveBeenCalled()

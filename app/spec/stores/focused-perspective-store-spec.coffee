_ = require 'underscore'

Actions = require('../../src/flux/actions').default
Folder = require('../../src/flux/models/folder').default
MailboxPerspective = require('../../src/mailbox-perspective').default

CategoryStore = require('../../src/flux/stores/category-store').default
AccountStore = require('../../src/flux/stores/account-store').default
FocusedPerspectiveStore = require('../../src/flux/stores/focused-perspective-store').default

describe "FocusedPerspectiveStore", ->
  beforeEach ->
    spyOn(FocusedPerspectiveStore, 'trigger')
    FocusedPerspectiveStore._current = MailboxPerspective.forNothing()
    @account = AccountStore.accounts()[0]

    @inboxCategory = new Folder(id: 'id-123', role: 'inbox', path: "INBOX", accountId: @account.id)
    @inboxPerspective = MailboxPerspective.forCategory(@inboxCategory)
    @userCategory = new Folder(id: 'id-456', role: null, path: "MyCategory", accountId: @account.id)
    @userPerspective = MailboxPerspective.forCategory(@userCategory)

    spyOn(CategoryStore, "getCategoryByRole").andReturn @inboxCategory
    spyOn(CategoryStore, "byId").andCallFake (aid, cid) =>
      return {id: 'A'} if aid is 1 and cid is 'A'
      return @inboxCategory if cid is @inboxCategory.id
      return @userCategory if cid is @userCategory.id
      return null

  describe "_initializeFromSavedState", ->
    beforeEach ->
      @default = MailboxPerspective.forCategory(@inboxCategory)
      spyOn(AccountStore, 'accountIds').andReturn([1, 2])
      spyOn(MailboxPerspective, 'fromJSON').andCallFake (json) -> json
      spyOn(FocusedPerspectiveStore, '_defaultPerspective').andReturn @default
      spyOn(FocusedPerspectiveStore, '_setPerspective')

    it "uses default perspective when no perspective has been saved", ->
      AppEnv.savedState.sidebarAccountIds = undefined
      AppEnv.savedState.perspective = undefined
      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(@default, @default.accountIds)

    it "uses default if the saved perspective has account ids no longer present", ->
      AppEnv.savedState.sidebarAccountIds = [1, 2, 3]
      AppEnv.savedState.perspective =
        accountIds: [1, 2, 3],
        categories: => [{accountId: 1, id: 'A'}],
      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(@default, @default.accountIds)

      AppEnv.savedState.sidebarAccountIds = [1, 2, 3]
      AppEnv.savedState.perspective =
        accountIds: [3]
        categories: => [{accountId: 3, id: 'A'}]
      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(@default, @default.accountIds)

    it "uses default if the saved perspective has category ids no longer present", ->
      AppEnv.savedState.sidebarAccountIds = [2]
      AppEnv.savedState.perspective =
        accountIds: [2]
        categories: => [{accountId: 2, id: 'C'}]
      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(@default, @default.accountIds)

    it "does not honor sidebarAccountIds if it includes account ids no longer present", ->
      AppEnv.savedState.sidebarAccountIds = [1, 2, 3]
      AppEnv.savedState.perspective =
        accountIds: [1]
        categories: => [{accountId: 1, id: 'A'}]
      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(AppEnv.savedState.perspective, [1])

    it "uses the saved perspective if it is still valid", ->
      AppEnv.savedState.sidebarAccountIds = [1, 2]
      AppEnv.savedState.perspective =
        accountIds: [1, 2]
        categories: => [{accountId: 1, id: 'A'}]
      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(AppEnv.savedState.perspective, [1, 2])

      AppEnv.savedState.sidebarAccountIds = [1, 2]
      AppEnv.savedState.perspective =
        accountIds: [1]
        categories: => []
        type: 'DraftsMailboxPerspective'

      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(AppEnv.savedState.perspective, [1, 2])

      AppEnv.savedState.sidebarAccountIds = [1]
      AppEnv.savedState.perspective =
        accountIds: [1]
        categories: => []
        type: 'DraftsMailboxPerspective'

      FocusedPerspectiveStore._initializeFromSavedState()
      expect(FocusedPerspectiveStore._setPerspective).toHaveBeenCalledWith(AppEnv.savedState.perspective, [1])

  describe "_onCategoryStoreChanged", ->
    it "should try to initialize if the curernt perspective hasn't been fully initialized", ->
      spyOn(FocusedPerspectiveStore, '_initializeFromSavedState')

      FocusedPerspectiveStore._current = @inboxPerspective
      FocusedPerspectiveStore._initialized = true
      FocusedPerspectiveStore._onCategoryStoreChanged()
      expect(FocusedPerspectiveStore._initializeFromSavedState).not.toHaveBeenCalled()

      FocusedPerspectiveStore._current = MailboxPerspective.forNothing()
      FocusedPerspectiveStore._initialized = false
      FocusedPerspectiveStore._onCategoryStoreChanged()
      expect(FocusedPerspectiveStore._initializeFromSavedState).toHaveBeenCalled()

    it "should set the current category to default when the current category no longer exists in the CategoryStore", ->
      defaultPerspective = @inboxPerspective
      FocusedPerspectiveStore._initialized = true
      spyOn(FocusedPerspectiveStore, '_defaultPerspective').andReturn(defaultPerspective)

      otherAccountInbox = @inboxCategory.clone()
      otherAccountInbox.id = 'other-id'
      FocusedPerspectiveStore._current = MailboxPerspective.forCategory(otherAccountInbox)

      FocusedPerspectiveStore._onCategoryStoreChanged()
      expect(FocusedPerspectiveStore.current()).toEqual(defaultPerspective)

  describe "_onFocusPerspective", ->
    it "should focus the category and trigger", ->
      FocusedPerspectiveStore._onFocusPerspective(@userPerspective)
      expect(FocusedPerspectiveStore.trigger).toHaveBeenCalled()
      expect(FocusedPerspectiveStore.current().categories()).toEqual([@userCategory])

  describe "_setPerspective", ->
    it "should not trigger if the perspective is already focused", ->
      FocusedPerspectiveStore._setPerspective(@inboxPerspective)
      FocusedPerspectiveStore.trigger.reset()
      FocusedPerspectiveStore._setPerspective(@inboxPerspective)
      expect(FocusedPerspectiveStore.trigger).not.toHaveBeenCalled()

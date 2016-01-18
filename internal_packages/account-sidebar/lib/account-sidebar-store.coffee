NylasStore = require 'nylas-store'
_ = require 'underscore'
{DatabaseStore,
 AccountStore,
 ThreadCountsStore,
 DraftCountStore,
 WorkspaceStore,
 MailboxPerspective,
 FocusedPerspectiveStore,
 DestroyCategoryTask,
 CategoryHelpers,
 CategoryStore} = require 'nylas-exports'

{AccountSidebarSection,
 CategorySidebarSection} = require './account-sidebar-sections'
{DraftListSidebarItem,
 MailboxPerspectiveSidebarItem} = require './account-sidebar-items'


Sections = {
  "Accounts"
  "Mailboxes"
  "Categories"
}

class AccountSidebarStore extends NylasStore

  constructor: ->
    @_sections = {}
    @_account = AccountStore.accounts()[0] # TODO Just to prevent a crash at launch
#    @_account = FocusedPerspectiveStore.current().account
    @_registerListeners()
    @_updateAccountsSection()
    @_updateSections()

  currentAccount: ->
    @_account

  accountsSection: ->
    @_sections[Sections.Accounts]

  mailboxesSection: ->
    @_sections[Sections.Mailboxes]

  categoriesSection: ->
    @_sections[Sections.Categories]

  _registerListeners: ->
    @listenTo ThreadCountsStore, @_updateSections
    @listenTo DraftCountStore, @_updateSections
    @listenTo CategoryStore, @_updateSections
    @listenTo FocusedPerspectiveStore, @_onPerspectiveChanged
    @configSubscription = NylasEnv.config.observe(
      'core.workspace.showUnreadForAllCategories',
      @_updateSections
    )
    @configSubscription = NylasEnv.config.observe(
      'core.accountSidebarCollapsed',
      @_updateSections
    )

  # TODO this needs to change
  _onPerspectiveChanged: =>
    account = FocusedPerspectiveStore.current().account
    if account?.id isnt @_account?.id
      @_account = account
      @_updateSections()
    @trigger()

  _onAccountsChanged: =>
    @_updateAccountsSection()
    @trigger()

  _updateSections: =>
    @_updateAccountsSection()
    @_updateMailboxesSection()
    @_updateCategoriesSection()
    @trigger()

  _updateAccountsSection: =>
    @_sections[Sections.Accounts] = new AccountSidebarSection(
      title: 'Accounts'
      items: []
    )

  _updateMailboxesSection: =>
    return unless @_account

    # Drafts are displayed via a `DraftListSidebarItem`
    standardCategories = CategoryStore.standardCategories(@_account)
    items = _.reject(standardCategories, (cat) => cat.name is "drafts")
      .map (cat) =>
        new MailboxPerspectiveSidebarItem(MailboxPerspective.forCategory(cat))

    starredItem = new MailboxPerspectiveSidebarItem(MailboxPerspective.forStarred([@_account.id]))
    draftsItem = new DraftListSidebarItem('Drafts', 'drafts.png', WorkspaceStore.Sheet.Drafts)

    # Order correctly: Inbox, Starred, rest... , Drafts
    items.splice(1, 0, starredItem)
    items.push(draftsItem)

    @_sections[Sections.Mailboxes] = new AccountSidebarSection(
      title: 'Mailboxes'
      items: items
    )

  _updateCategoriesSection: =>
    return unless @_account

    # Compute hierarchy for user categories using known "path" separators
    # NOTE: This code uses the fact that userCategoryItems is a sorted set, eg:
    #
    # Inbox
    # Inbox.FolderA
    # Inbox.FolderA.FolderB
    # Inbox.FolderB
    #
    items = []
    seenItems = {}
    for category in CategoryStore.userCategories(@_account)
      # https://regex101.com/r/jK8cC2/1
      itemKey = category.displayName.replace(/[./\\]/g, '/')
      perspective = MailboxPerspective.forCategory(@_account, category)

      parent = null
      parentComponents = itemKey.split('/')
      for i in [parentComponents.length..1] by -1
        parentKey = parentComponents[0...i].join('/')
        parent = seenItems[parentKey]
        break if parent

      if parent
        itemDisplayName = category.displayName.substr(parentKey.length+1)
        item = new MailboxPerspectiveSidebarItem(perspective, itemDisplayName)
        parent.children.push(item)
      else
        item = new MailboxPerspectiveSidebarItem(perspective)
        items.push(item)
      seenItems[itemKey] = item

    @_sections[Sections.Categories] = new CategorySidebarSection(
      title: CategoryHelpers.categoryLabel(@_account)
      iconName: CategoryHelpers.categoryIconName(@_account)
      account: @_account
      items: items
    )


module.exports = new AccountSidebarStore()

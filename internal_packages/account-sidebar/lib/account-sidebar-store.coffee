NylasStore = require 'nylas-store'
_ = require 'underscore'
{DatabaseStore,
 AccountStore,
 CategoryStore,
 ThreadCountsStore,
 WorkspaceStore,
 Actions,
 Label,
 Folder,
 Message,
 MailViewFilter,
 FocusedMailViewStore,
 SyncbackCategoryTask,
 DestroyCategoryTask,
 CategoryHelpers,
 Thread} = require 'nylas-exports'

class AccountSidebarStore extends NylasStore
  constructor: ->
    @_sections = []
    @_account = AccountStore.accounts()[0] # TODO Temporarily, should be null
    @_registerListeners()
    @_updateSections()

  ########### PUBLIC #####################################################

  currentAccount: ->
    @_account

  sections: ->
    @_sections

  selected: ->
    if WorkspaceStore.rootSheet() is WorkspaceStore.Sheet.Threads
      FocusedMailViewStore.mailView()
    else
      WorkspaceStore.rootSheet()

  ########### PRIVATE ####################################################

  _registerListeners: ->
    @listenTo WorkspaceStore, @_updateSections
    @listenTo CategoryStore, @_updateSections
    @listenTo ThreadCountsStore, @_updateSections
    @listenTo FocusedMailViewStore, => @trigger()
    @listenTo Actions.selectAccount, @_onSelectAccount
    @configSubscription = NylasEnv.config.observe(
      'core.workspace.showUnreadForAllCategories',
      @_updateSections
    )

  _onSelectAccount: (accountId)=>
    @_account = AccountStore.accountForId(accountId)
    @trigger()

  _updateSections: =>
    # TODO As it is now, if the current account is null, we  will display the
    # categories for all accounts.
    # Update this to reflect UI decision for sidebar
    userCategories = CategoryStore.userCategories(@_account)
    userCategoryItems = _.map(userCategories, @_sidebarItemForCategory)

    # Compute hierarchy for userCategoryItems using known "path" separators
    # NOTE: This code uses the fact that userCategoryItems is a sorted set, eg:
    #
    # Inbox
    # Inbox.FolderA
    # Inbox.FolderA.FolderB
    # Inbox.FolderB
    #
    userCategoryItemsHierarchical = []
    userCategoryItemsSeen = {}
    for category in userCategories
      # https://regex101.com/r/jK8cC2/1
      itemKey = category.displayName.replace(/[./\\]/g, '/')

      parent = null
      parentComponents = itemKey.split('/')
      for i in [parentComponents.length..1] by -1
        parentKey = parentComponents[0...i].join('/')
        parent = userCategoryItemsSeen[parentKey]
        break if parent

      if parent
        itemDisplayName = category.displayName.substr(parentKey.length+1)
        item = @_sidebarItemForCategory(category, itemDisplayName)
        parent.children.push(item)
      else
        item = @_sidebarItemForCategory(category)
        userCategoryItemsHierarchical.push(item)
      userCategoryItemsSeen[itemKey] = item

    # Our drafts are displayed via the `DraftListSidebarItem` which
    # is loading into the `Drafts` Sheet.
    standardCategories = CategoryStore.standardCategories(@_account)
    standardCategories = _.reject standardCategories, (category) =>
      category.name is "drafts"

    standardCategoryItems = _.map standardCategories, (cat) => @_sidebarItemForCategory(cat)
    starredItem = @_sidebarItemForMailView('starred', MailViewFilter.forStarred(@_account))

    # Find root views and add them to the bottom of the list (Drafts, etc.)
    standardItems = standardCategoryItems
    standardItems.splice(1, 0, starredItem)

    customSections = {}
    for item in WorkspaceStore.sidebarItems()
      if item.section
        customSections[item.section] ?= []
        customSections[item.section].push(item)
      else
        standardItems.push(item)

    @_sections = []
    @_sections.push
      label: 'Mailboxes'
      items: standardItems

    for section, items of customSections
      @_sections.push
        label: section
        items: items

    @_sections.push
      label: CategoryHelpers.categoryLabel(@_account)
      items: userCategoryItemsHierarchical
      iconName: CategoryHelpers.categoryIconName(@_account)
      createItem: @_createCategory
      destroyItem: @_destroyCategory

    @trigger()

  _sidebarItemForMailView: (id, filter) =>
    new WorkspaceStore.SidebarItem
      id: id,
      name: filter.name,
      mailViewFilter: filter

  _sidebarItemForCategory: (category, shortenedName) =>
    new WorkspaceStore.SidebarItem
      id: category.id,
      name: shortenedName || category.displayName
      mailViewFilter: MailViewFilter.forCategory(@_account, category)
      unreadCount: @_itemUnreadCount(category)

  _createCategory: (displayName) ->
    # TODO this needs an account param
    return unless @_account?
    CategoryClass = @_account.categoryClass()
    category = new CategoryClass
      displayName: displayName
      accountId: @_account.id
    Actions.queueTask(new SyncbackCategoryTask({category}))

  _destroyCategory: (sidebarItem) ->
    category = sidebarItem.mailViewFilter.category
    return if category.isDeleted is true
    Actions.queueTask(new DestroyCategoryTask({category}))

  _itemUnreadCount: (category) =>
    unreadCountEnabled = NylasEnv.config.get('core.workspace.showUnreadForAllCategories')
    if category and (category.name is 'inbox' or unreadCountEnabled)
      return ThreadCountsStore.unreadCountForCategoryId(category.id)
    return 0

module.exports = new AccountSidebarStore()

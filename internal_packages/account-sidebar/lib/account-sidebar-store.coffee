NylasStore = require 'nylas-store'
_ = require 'underscore'
{CategoryStore,
 DatabaseStore,
 CategoryStore,
 AccountStore,
 WorkspaceStore,
 DraftCountStore,
 Actions,
 Label,
 Folder,
 Message,
 MailViewFilter,
 FocusedMailViewStore,
 NylasAPI,
 Thread} = require 'nylas-exports'

class AccountSidebarStore extends NylasStore
  constructor: ->
    @_sections = []
    @_registerListeners()
    @_refreshSections()

  ########### PUBLIC #####################################################

  sections: ->
    @_sections

  selected: ->
    if WorkspaceStore.rootSheet() is WorkspaceStore.Sheet.Threads
      FocusedMailViewStore.mailView()
    else
      WorkspaceStore.rootSheet()

  ########### PRIVATE ####################################################

  _registerListeners: ->
    @listenTo CategoryStore, @_refreshSections
    @listenTo WorkspaceStore, @_refreshSections
    @listenTo DraftCountStore, @_refreshSections
    @listenTo FocusedMailViewStore, => @trigger()

  _refreshSections: =>
    account = AccountStore.current()
    return unless account

    userCategories = CategoryStore.getUserCategories()
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
    standardCategories = CategoryStore.getStandardCategories()
    standardCategories = _.reject standardCategories, (category) =>
      category.name is "drafts"

    standardCategoryItems = _.map standardCategories, (cat) => @_sidebarItemForCategory(cat)
    starredItem = @_sidebarItemForMailView('starred', MailViewFilter.forStarred())

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
      label: CategoryStore.categoryLabel()
      items: userCategoryItemsHierarchical

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
      mailViewFilter: MailViewFilter.forCategory(category)

module.exports = new AccountSidebarStore()

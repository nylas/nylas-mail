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

    # Our drafts are displayed via the `DraftListSidebarItem` which
    # is loading into the `Drafts` Sheet.
    standardCategories = CategoryStore.getStandardCategories()
    standardCategories = _.reject standardCategories, (category) =>
      category.name is "drafts"

    standardCategoryItems = _.map(standardCategories, @_sidebarItemForCategory)
    starredItem = @_sidebarItemForMailView('starred', MailViewFilter.forStarred())

    # Find root views and add them to the bottom of the list (Drafts, etc.)
    standardItems = standardCategoryItems
    standardItems.splice(1, 0, starredItem)
    standardItems.push(WorkspaceStore.sidebarItems()...)

    @_sections = []
    @_sections.push
      label: 'Mailboxes'
      items: standardItems
      type: 'mailboxes'

    @_sections.push
      label: CategoryStore.categoryLabel()
      items: userCategoryItems
      type: 'category'

    @trigger()

  _sidebarItemForMailView: (id, filter) =>
    new WorkspaceStore.SidebarItem({id: id, name: filter.name, mailViewFilter: filter})

  _sidebarItemForCategory: (category) =>
    filter = MailViewFilter.forCategory(category)
    @_sidebarItemForMailView(category.id, filter)


module.exports = new AccountSidebarStore()

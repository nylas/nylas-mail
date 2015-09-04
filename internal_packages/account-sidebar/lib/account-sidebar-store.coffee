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

    viewFilterForCategory = (cat) ->
      return MailViewFilter.forCategory(cat)

    userCategories = CategoryStore.getUserCategories()
    userCategoryViews = _.map(userCategories, viewFilterForCategory)

    # Our drafts are displayed via the `DraftListSidebarItem` which
    # is loading into the `Drafts` Sheet.
    standardCategories = CategoryStore.getStandardCategories()
    standardCategories = _.reject standardCategories, (category) =>
      category.name is "drafts"

    standardViews = _.map(standardCategories, viewFilterForCategory)
    standardViews.push(WorkspaceStore.Sheet["Drafts"])

    starredView = MailViewFilter.forStarred()
    standardViews.splice(1, 0, starredView)

    # Find root views, add the Views section
    # featureSheets = _.filter WorkspaceStore.Sheet, (sheet) ->
    #   sheet.name in ['Today']
    # extraSheets = _.filter WorkspaceStore.Sheet, (sheet) ->
    #   sheet.root and sheet.name and not (sheet in featureSheets)

    @_sections = []
    # if featureSheets.length > 0
    #   @_sections.push { label: '', items: featureSheets, type: 'sheet' }
    @_sections.push
      label: 'Mailboxes'
      items: standardViews
      type: 'mailboxes'
    # @_sections.push { label: 'Views', items: extraSheets, type: 'sheet' }
    @_sections.push
      label: CategoryStore.categoryLabel()
      items: userCategoryViews
      type: 'category'

    @trigger()

  _isStandardCategory: (category) =>
    category.name and category.name in CategoryStore.standardCategories

module.exports = new AccountSidebarStore()

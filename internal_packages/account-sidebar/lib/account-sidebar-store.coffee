NylasStore = require 'nylas-store'
_ = require 'underscore'
{CategoryStore,
 DatabaseStore,
 CategoryStore,
 NamespaceStore,
 WorkspaceStore,
 DraftCountStore,
 Actions,
 Label,
 Folder,
 Message,
 FocusedCategoryStore,
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
      FocusedCategoryStore.category()
    else
      WorkspaceStore.rootSheet()

  ########### PRIVATE ####################################################

  _registerListeners: ->
    @listenTo CategoryStore, @_refreshSections
    @listenTo WorkspaceStore, @_refreshSections
    @listenTo DraftCountStore, @_refreshSections
    @listenTo FocusedCategoryStore, => @trigger()

  _refreshSections: =>
    namespace = NamespaceStore.current()
    return unless namespace

    categories = CategoryStore.categories()

    # Categories need to be fetched from the DB, and if necessary the API.
    # They might not be ready yet.
    return unless categories.length > 0

    # We ignore the server drafts so we can use our own localDrafts
    #
    # Our local drafts are displayed via the `DraftListSidebarItem` which
    # is loading into the `Drafts` Sheet.
    categories = _.reject categories, (category) =>
      category.name is "drafts"

    # Collect the built-in categories we want to display, and the user
    # categories (which can be identified by having non-hardcoded IDs)
    standardCategories = _.filter categories, @_isStandardCategory
    userCategories = _.reject categories, @_isStandardCategory

    # Sort the standard categories so they always appear in the same order
    standardCategories = _.sortBy standardCategories, (category) =>
      CategoryStore.standardCategories.indexOf(category.name)

    # Sort user categories by name
    userCategories = _.sortBy(userCategories, 'displayName')

    # Find root views, add the Views section
    featureSheets = _.filter WorkspaceStore.Sheet, (sheet) ->
      sheet.name in ['Today']
    extraSheets = _.filter WorkspaceStore.Sheet, (sheet) ->
      sheet.root and sheet.name and not (sheet in featureSheets)

    @_sections = []
    if featureSheets.length > 0
      @_sections.push { label: '', items: featureSheets, type: 'sheet' }
    @_sections.push { label: 'Mailboxes', items: standardCategories, type: 'category' }
    @_sections.push { label: 'Views', items: extraSheets, type: 'sheet' }
    @_sections.push { label: CategoryStore.categoryLabel(), items: userCategories, type: 'category' }

    @trigger()

  _isStandardCategory: (category) =>
    category.name and category.name in CategoryStore.standardCategories

module.exports = new AccountSidebarStore()

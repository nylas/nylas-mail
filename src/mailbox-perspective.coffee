_ = require 'underscore'

TaskFactory = require './flux/tasks/task-factory'
AccountStore = require './flux/stores/account-store'
CategoryStore = require './flux/stores/category-store'
DatabaseStore = require './flux/stores/database-store'
SearchSubscription = require './search-subscription'
ThreadCountsStore = require './flux/stores/thread-counts-store'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'
Thread = require './flux/models/thread'
Actions = require './flux/actions'

# This is a class cluster. Subclasses are not for external use!
# https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html

class MailboxPerspective

  # Factory Methods
  @forNothing: ->
    new EmptyMailboxPerspective()

  @forDrafts: (accountsOrIds) ->
    new DraftsMailboxPerspective(accountsOrIds)

  @forCategory: (category) ->
    return @forNothing() unless category
    new CategoryMailboxPerspective([category])

  @forCategories: (categories) ->
    return @forNothing() if categories.length is 0
    new CategoryMailboxPerspective(categories)

  @forStandardCategories: (accountsOrIds, names...) ->
    categories = CategoryStore.getStandardCategories(accountsOrIds, names...)
    @forCategories(categories)

  @forStarred: (accountsOrIds) ->
    new StarredMailboxPerspective(accountsOrIds)

  @forSearch: (accountsOrIds, query) ->
    new SearchMailboxPerspective(accountsOrIds, query)

  @forInbox: (accountsOrIds) =>
    @forStandardCategories(accountsOrIds, 'inbox')

  @forAll: (accountsOrIds) =>
    @forStandardCategories(accountsOrIds, 'all')


  # Instance Methods

  constructor: (@accountIds) ->
    unless @accountIds instanceof Array and _.every(@accountIds, _.isString)
      throw new Error("#{@constructor.name}: You must provide an array of string `accountIds`")
    @

  isEqual: (other) =>
    return false unless other and @constructor is other.constructor
    return false unless other.name is @name
    return false unless _.isEqual(@accountIds, other.accountIds)
    true

  categories: =>
    []

  category: =>
    return null unless @categories().length isnt 0
    return @categories()[0]

  threads: =>
    throw new Error("threads: Not implemented in base class.")

  threadUnreadCount: =>
    0

  canApplyToThreads: =>
    throw new Error("canApplyToThreads: Not implemented in base class.")

  applyToThreads: (threadsOrIds) =>
    throw new Error("applyToThreads: Not implemented in base class.")

  # Whether or not the current MailboxPerspective can "archive" or "trash"
  # Subclasses should call `super` if they override these methods
  canArchiveThreads: =>
    for aid in @accountIds
      return false unless CategoryStore.getArchiveCategory(AccountStore.accountForId(aid))
    return true

  canTrashThreads: =>
    for aid in @accountIds
      return false unless CategoryStore.getTrashCategory(AccountStore.accountForId(aid))
    return true

  isInbox: =>
    false

class SearchMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds, @searchQuery) ->
    super(@accountIds)

    unless _.isString(@searchQuery)
      throw new Error("SearchMailboxPerspective: Expected a `string` search query")

    @

  isEqual: (other) =>
    super(other) and other.searchQuery is @searchQuery

  threads: =>
    new SearchSubscription(@searchQuery, @accountIds)

  canApplyToThreads: =>
    false

  canArchiveThreads: =>
    false

  canTrashThreads: =>
    false


class DraftsMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds) ->
    super(@accountIds)
    @name = "Drafts"
    @iconName = "drafts.png"
    @drafts = true # The DraftListStore looks for this
    @

  threads: =>
    null

  canApplyToThreads: =>
    false

class StarredMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds) ->
    super(@accountIds)
    @name = "Starred"
    @iconName = "starred.png"
    @

  threads: =>
    query = DatabaseStore.findAll(Thread).where([
      Thread.attributes.accountId.in(@accountIds),
      Thread.attributes.starred.equal(true)
    ]).limit(0)

    return new MutableQuerySubscription(query, {asResultSet: true})

  canApplyToThreads: =>
    true

  applyToThreads: (threadsOrIds) =>
    ChangeStarredTask = require './flux/tasks/change-starred-task'
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true})
    Actions.queueTask(task)


class EmptyMailboxPerspective extends MailboxPerspective
  constructor: ->
    @accountIds = []

  threads: =>
    query = DatabaseStore.findAll(Thread).where(accountId: -1).limit(0)
    return new MutableQuerySubscription(query, {asResultSet: true})

  canApplyToThreads: =>
    false

  canArchiveThreads: =>
    false

  canTrashThreads: =>
    false

  applyToThreads: (threadsOrIds) =>


class CategoryMailboxPerspective extends MailboxPerspective
  constructor: (@_categories) ->
    super(_.uniq(_.pluck(@_categories, 'accountId')))

    if @_categories.length is 0
      throw new Error("CategoryMailboxPerspective: You must provide at least one category.")

    # Note: We pick the display name and icon assuming that you won't create a
    # perspective with Inbox and Sent or anything crazy like that... todo?
    @name = @_categories[0].displayName
    if @_categories[0].name
      @iconName = "#{@_categories[0].name}.png"
    else
      @iconName = AccountStore.accountForId(@accountIds[0]).categoryIcon()

    @

  isEqual: (other) =>
    super(other) and _.isEqual(@categories(), other.categories())

  threads: =>
    query = DatabaseStore
      .findAll(Thread)
      .where([Thread.attributes.categories.containsAny(_.pluck(@categories(), 'id'))])
      .limit(0)

    if @_categories.length > 1 and @accountIds.length < @_categories.length
      # The user has multiple categories in the same account selected, which
      # means our result set could contain multiple copies of the same threads
      # (since we do an inner join) and we need SELECT DISTINCT. Note that this
      # can be /much/ slower and we shouldn't do it if we know we don't need it.
      query.distinct()

    return new MutableQuerySubscription(query, {asResultSet: true})

  threadUnreadCount: =>
    sum = 0
    for cat in @_categories
      sum += ThreadCountsStore.unreadCountForCategoryId(cat.id)
    sum

  categories: =>
    @_categories

  isInbox: =>
    @_categories[0].name is 'inbox'

  canApplyToThreads: =>
    not _.any @_categories, (c) -> c.isLockedCategory()

  canArchiveThreads: =>
    for cat in @_categories
      return false if cat.name in ["archive", "all", "sent"]
    super

  canTrashThreads: =>
    for cat in @_categories
      return false if cat.name in ["trash"]
    super

  applyToThreads: (threadsOrIds) =>
    FocusedPerspectiveStore = require './flux/stores/focused-perspective-store'
    currentCategories = FocusedPerspectiveStore.current().categories()

    DatabaseStore.modelify(Thread, threadsOrIds).then (threads) =>
      tasks = TaskFactory.tasksForApplyingCategories
        threads: threads
        categoriesToRemove: (accountId) -> _.filter(currentCategories, _.matcher({accountId}))
        categoryToAdd: (accountId) => _.findWhere(@_categories, {accountId})
      Actions.queueTasks(tasks)

module.exports = MailboxPerspective

_ = require 'underscore'

TaskFactory = require './flux/tasks/task-factory'
AccountStore = require './flux/stores/account-store'
CategoryStore = require './flux/stores/category-store'
DatabaseStore = require './flux/stores/database-store'
OutboxStore = require './flux/stores/outbox-store'
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
    return null unless @categories().length is 1
    return @categories()[0]

  threads: =>
    throw new Error("threads: Not implemented in base class.")

  unreadCount: =>
    0

  # Public:
  # - accountIds {Array} Array of unique account ids associated with the threads
  # that want to be included in this perspective
  #
  # Returns true if the accountIds are part of the current ids, or false
  # otherwise. This means that it checks if I am moving trying to move threads
  # betwee the same set of accounts:
  #
  # E.g.:
  # perpective = Starred for accountIds: a1, a2
  # thread1 has accountId a3
  # thread2 has accountId a2
  #
  # perspective.canReceiveThreads([a2, a3]) -> false -> I cant move those threads to Starred
  # perspective.canReceiveThreads([a2]) -> true -> I can move that thread to # Starred
  canReceiveThreads: (accountIds) =>
    return false unless accountIds and accountIds.length > 0
    incomingIdsInCurrent = _.difference(accountIds, @accountIds).length is 0
    return incomingIdsInCurrent

  receiveThreads: (threadsOrIds) =>
    throw new Error("receiveThreads: Not implemented in base class.")

  removeThreads: (threadsOrIds) =>
    # Don't throw an error here because we just want it to be a no op if not
    # implemented
    return

  # Whether or not the current MailboxPerspective can "archive" or "trash"
  # Subclasses should call `super` if they override these methods
  canArchiveThreads: =>
    for aid in @accountIds
      return false unless CategoryStore.getArchiveCategory(aid)
    return true

  canTrashThreads: =>
    for aid in @accountIds
      return false unless CategoryStore.getTrashCategory(aid)
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

  canReceiveThreads: =>
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

  unreadCount: =>
    count = 0
    count += OutboxStore.itemsForAccount(aid).length for aid in @accountIds
    count

  canReceiveThreads: =>
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

  canReceiveThreads: =>
    super

  receiveThreads: (threadsOrIds) =>
    ChangeStarredTask = require './flux/tasks/change-starred-task'
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true})
    Actions.queueTask(task)

  removeThreads: (threadsOrIds) =>
    task = TaskFactory.taskForInvertingStarred(threads: threadsOrIds)
    Actions.queueTask(task)

class EmptyMailboxPerspective extends MailboxPerspective
  constructor: ->
    @accountIds = []

  threads: =>
    query = DatabaseStore.findAll(Thread).where(accountId: -1).limit(0)
    return new MutableQuerySubscription(query, {asResultSet: true})

  canReceiveThreads: =>
    false

  canArchiveThreads: =>
    false

  canTrashThreads: =>
    false

  receiveThreads: (threadsOrIds) =>


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
    query = DatabaseStore.findAll(Thread)
      .where([Thread.attributes.categories.containsAny(_.pluck(@categories(), 'id'))])
      .limit(0)

    if @_categories.length > 1 and @accountIds.length < @_categories.length
      # The user has multiple categories in the same account selected, which
      # means our result set could contain multiple copies of the same threads
      # (since we do an inner join) and we need SELECT DISTINCT. Note that this
      # can be /much/ slower and we shouldn't do it if we know we don't need it.
      query.distinct()

    return new MutableQuerySubscription(query, {asResultSet: true})

  unreadCount: =>
    sum = 0
    for cat in @_categories
      sum += ThreadCountsStore.unreadCountForCategoryId(cat.id)
    sum

  categories: =>
    @_categories

  isInbox: =>
    @_categories[0].name is 'inbox'

  canReceiveThreads: =>
    super and not _.any @_categories, (c) -> c.isLockedCategory()

  canArchiveThreads: =>
    for cat in @_categories
      return false if cat.name in ["archive", "all", "sent"]
    super

  canTrashThreads: =>
    for cat in @_categories
      return false if cat.name in ["trash"]
    super

  receiveThreads: (threadsOrIds) =>
    FocusedPerspectiveStore = require './flux/stores/focused-perspective-store'
    currentCategories = FocusedPerspectiveStore.current().categories()

    # This assumes that the we don't have more than one category per accountId
    # attached to this perspective
    DatabaseStore.modelify(Thread, threadsOrIds).then (threads) =>
      tasks = TaskFactory.tasksForApplyingCategories
        threads: threadsOrIds
        categoriesToRemove: (accountId) -> _.filter(currentCategories, _.matcher({accountId}))
        categoryToAdd: (accountId) => _.findWhere(@_categories, {accountId})
      Actions.queueTasks(tasks)

  removeThreads: (threadsOrIds) =>
    DatabaseStore.modelify(Thread, threadsOrIds).then (threads) =>
      isTrash = not @canTrashThreads()
      isNotArchiveOrSent = @canArchiveThreads()

      tasks = null
      categories = @categories()

      if @isInbox()
        tasks = TaskFactory.tasksForRemovingCategories({
          threads,
          categories,
          moveToFinishedCategory: true
        })
      else if isTrash
        tasks = TaskFactory.tasksForMovingToInbox({threads, categories})
      else if isNotArchiveOrSent
        tasks = TaskFactory.tasksForRemovingCategories({
          threads,
          categories,
          moveToFinishedCategory: false
        })
      else
        return

      Actions.queueTasks(tasks)

module.exports = MailboxPerspective

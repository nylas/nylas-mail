_ = require 'underscore'

Utils = require './flux/models/utils'
TaskFactory = require './flux/tasks/task-factory'
AccountStore = require './flux/stores/account-store'
CategoryStore = require './flux/stores/category-store'
DatabaseStore = require './flux/stores/database-store'
OutboxStore = require './flux/stores/outbox-store'
SearchQuerySubscription = require './search-query-subscription'
ThreadCountsStore = require './flux/stores/thread-counts-store'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'
Thread = require './flux/models/thread'
Category = require './flux/models/category'
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

  @fromJSON: (json) =>
    try
      if json.type is CategoryMailboxPerspective.name
        categories = JSON.parse(json.serializedCategories, Utils.registeredObjectReviver)
        return @forCategories(categories)
      else if json.type is SearchMailboxPerspective.name
        return @forSearch(json.accountIds, json.searchQuery)
      else if json.type is StarredMailboxPerspective.name
        return @forStarred(json.accountIds)
      else if json.type is DraftsMailboxPerspective.name
        return @forDrafts(json.accountIds)
      else
        return null
    catch error
      NylasEnv.reportError(new Error("Could not restore mailbox perspective: #{error}"))
      return null

  # Instance Methods

  constructor: (@accountIds) ->
    unless @accountIds instanceof Array and _.every(@accountIds, _.isString)
      throw new Error("#{@constructor.name}: You must provide an array of string `accountIds`")
    @

  toJSON: =>
    return {accountIds: @accountIds, type: @constructor.name}

  isEqual: (other) =>
    return false unless other and @constructor is other.constructor
    return false unless other.name is @name
    return false unless _.isEqual(@accountIds, other.accountIds)
    true

  isInbox: =>
    @categoriesSharedName() is 'inbox'

  isSent: =>
    @categoriesSharedName() is 'sent'

  isTrash: =>
    @categoriesSharedName() is 'trash'

  isArchive: =>
    false

  isSearch: =>
    @ instanceof SearchMailboxPerspective

  categories: =>
    []

  categoriesSharedName: =>
    @_categoriesSharedName ?= Category.categoriesSharedName(@categories())
    @_categoriesSharedName

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
  # otherwise. This means that it checks if I am attempting to move threads
  # between the same set of accounts:
  #
  # E.g.:
  # perpective = Starred for accountIds: a1, a2
  # thread1 has accountId a3
  # thread2 has accountId a2
  #
  # perspective.canReceiveThreadsFromAccountIds([a2, a3]) -> false -> I cant move those threads to Starred
  # perspective.canReceiveThreadsFromAccountIds([a2]) -> true -> I can move that thread to # Starred
  canReceiveThreadsFromAccountIds: (accountIds) =>
    return false unless accountIds and accountIds.length > 0
    areIncomingIdsInCurrent = _.difference(accountIds, @accountIds).length is 0
    return areIncomingIdsInCurrent

  receiveThreads: (threadsOrIds) =>
    throw new Error("receiveThreads: Not implemented in base class.")

  canArchiveThreads: (threads) =>
    accounts = AccountStore.accountsForItems(threads)
    accountsCanArchiveThreads = _.every(accounts, (acc) -> acc.canArchiveThreads())
    return (not @isArchive()) and accountsCanArchiveThreads

  canTrashThreads: (threads) =>
    accounts = AccountStore.accountsForItems(threads)
    accountCanTrashThreads = _.every(accounts, (acc) -> acc.canTrashThreads())
    return (not @isTrash()) and accountCanTrashThreads

  tasksForRemovingItems: (threads) =>
    if not threads instanceof Array
      throw new Error("tasksForRemovingItems: you must pass an array of threads or thread ids")
    []


class SearchMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds, @searchQuery) ->
    super(@accountIds)
    @name = 'Search'

    unless _.isString(@searchQuery)
      throw new Error("SearchMailboxPerspective: Expected a `string` search query")

    @

  toJSON: =>
    json = super
    json.searchQuery = @searchQuery
    json

  isEqual: (other) =>
    super(other) and other.searchQuery is @searchQuery

  threads: =>
    new SearchQuerySubscription(@searchQuery, @accountIds)

  canReceiveThreadsFromAccountIds: =>
    false

  tasksForRemovingItems: (threads) =>
    TaskFactory.tasksForApplyingCategories(
      threads: threads,
      categoriesToAdd: (accountId) =>
        account = AccountStore.accountForId(accountId)
        return [account.defaultFinishedCategory()]
    )

class DraftsMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds) ->
    super(@accountIds)
    @name = "Drafts"
    @iconName = "drafts.png"
    @drafts = true # The DraftListStore looks for this
    @

  fromJSON: =>
    {type: @constructor.name, accountIds: @accountIds}

  threads: =>
    null

  unreadCount: =>
    count = 0
    count += OutboxStore.itemsForAccount(aid).length for aid in @accountIds
    count

  canReceiveThreadsFromAccountIds: =>
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
      Thread.attributes.starred.equal(true),
      Thread.attributes.inAllMail.equal(true),
    ]).limit(0)

    return new MutableQuerySubscription(query, {asResultSet: true})

  canReceiveThreadsFromAccountIds: =>
    super

  receiveThreads: (threadsOrIds) =>
    ChangeStarredTask = require './flux/tasks/change-starred-task'
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true})
    Actions.queueTask(task)

  tasksForRemovingItems: (threads) =>
    task = TaskFactory.taskForInvertingStarred(threads: threads)
    return [task]


class EmptyMailboxPerspective extends MailboxPerspective
  constructor: ->
    @accountIds = []

  threads: =>
    query = DatabaseStore.findAll(Thread).where(accountId: -1).limit(0)
    return new MutableQuerySubscription(query, {asResultSet: true})

  canReceiveThreadsFromAccountIds: =>
    false


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

  toJSON: =>
    json = super
    json.serializedCategories = JSON.stringify(@_categories, Utils.registeredObjectReplacer)
    json

  isEqual: (other) =>
    super(other) and _.isEqual(_.pluck(@categories(), 'id'), _.pluck(other.categories(), 'id'))

  threads: =>
    query = DatabaseStore.findAll(Thread)
      .where([Thread.attributes.categories.containsAny(_.pluck(@categories(), 'id'))])
      .limit(0)

    if @isSent()
      query.order(Thread.attributes.lastMessageSentTimestamp.descending())

    unless @categoriesSharedName() in ['spam', 'trash']
      query.where(inAllMail: true)

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

  isArchive: =>
    _.every(@_categories, (cat) -> cat.isArchive())

  canReceiveThreadsFromAccountIds: =>
    super and not _.any @_categories, (c) -> c.isLockedCategory()

  receiveThreads: (threadsOrIds) =>
    FocusedPerspectiveStore = require './flux/stores/focused-perspective-store'
    current= FocusedPerspectiveStore.current()

    # This assumes that the we don't have more than one category per accountId
    # attached to this perspective
    DatabaseStore.modelify(Thread, threadsOrIds).then (threads) =>
      tasks = TaskFactory.tasksForApplyingCategories
        threads: threads
        categoriesToRemove: (accountId) ->
          if current.categoriesSharedName() in Category.LockedCategoryNames
            return []
          return _.filter(current.categories(), _.matcher({accountId}))
        categoriesToAdd: (accountId) => [_.findWhere(@_categories, {accountId})]
      Actions.queueTasks(tasks)

  # Public:
  # Returns the tasks for removing threads from this perspective and moving them
  # to a given target/destination based on a {RemovalTargetRuleset}.
  #
  # A RemovalTargetRuleset for categories is a map that represents the
  # target/destination Category when removing threads from another given
  # category, i.e., when removing them the current CategoryPerspective.
  # Rulesets are of the form:
  #
  #   [categoryName] -> function(accountId): Category
  #
  # Keys correspond to category names, e.g.`{'inbox', 'trash',...}`, which
  # correspond to the name of the categories associated with the current perspective
  # Values are functions with the following signature:
  #
  #   `function(accountId): Category`
  #
  # If the value of the category name of the current perspective is null instead
  # of a function, this method will return an empty array of tasks
  #
  # RemovalRulesets should also contain a key `other`, that is meant to be used
  # when a key cannot be found for the current category name
  #
  # Example:
  # perspective.tasksForRemovingItems(
  #   threads,
  #   {
  #     # Move to trash if the current perspective is inbox
  #     inbox: (accountId) -> CategoryStore.getTrashCategory(accountId),
  #
  #     # Do nothing if the current perspective is trash
  #     trash: null,
  #   }
  # )
  #
  tasksForRemovingItems: (threads, ruleset) =>
    if not ruleset
      throw new Error("tasksForRemovingItems: you must pass a ruleset object to determine the destination of the threads")

    name = if @isArchive()
      # TODO this is an awful hack
      'archive'
    else
      @categoriesSharedName()

    return [] if ruleset[name] is null

    return TaskFactory.tasksForApplyingCategories(
      threads: threads,
      categoriesToRemove: (accountId) =>
        # Remove all categories from this perspective that match the accountId
        return _.filter(@_categories, _.matcher({accountId}))
      categoriesToAdd: (accId) =>
        category = (ruleset[name] ? ruleset.other)(accId)
        return if category then [category] else []
    )


module.exports = MailboxPerspective

_ = require 'underscore'

AccountStore = require './flux/stores/account-store'
CategoryStore = require './flux/stores/category-store'
DatabaseStore = require './flux/stores/database-store'
SearchSubscription = require './search-subscription'
ThreadCountsStore = require './flux/stores/thread-counts-store'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'
CategoryHelpers = require './category-helpers'
Thread = require './flux/models/thread'
Actions = require './flux/actions'

# This is a class cluster. Subclasses are not for external use!
# https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html

class MailboxPerspective

  # Factory Methods
  @forNothing: ->
    new EmptyMailboxPerspective()

  @forCategory: (category) ->
    new CategoryMailboxPerspective([category])

  @forCategories: (categories) ->
    new CategoryMailboxPerspective(categories)

  @forStarred: (accountIds) ->
    new StarredMailboxPerspective(accountIds)

  @forSearch: (accountIds, query) ->
    new SearchMailboxPerspective(accountIds, query)

  @forAll: (accountIds) ->
    categories = accountIds.map (aid) ->
      CategoryStore.getStandardCategory(aid, "all")
    new CategoryMailboxPerspective(_.compact(categories))

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
      @iconName = CategoryHelpers.categoryIconName(@accountIds[0])

    @

  isEqual: (other) =>
    super(other) and _.isEqual(@categories(), other.categories())

  threads: =>
    query = DatabaseStore
      .findAll(Thread)
      .where([Thread.attributes.categories.containsAny(_.pluck(@categories(), 'id'))])
      .limit(0)

    query.distinct() if @categories().length > 1

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
    # TODO:
    # categoryToApplyForAccount = {}
    # for cat in @_categories
    #   categoryToApplyForAccount[cat.accountId] = cat
    #
    # @_categories.forEach (cat) ->
    #
    # if @account.usesLabels()
    #   FocusedPerspectiveStore = require './flux/stores/focused-perspective-store'
    #   currentLabel = FocusedPerspectiveStore.current().category
    #   if currentLabel and not (currentLabel.isLockedCategory())
    #     labelsToRemove = [currentLabel]
    #
    #   ChangeLabelsTask = require './flux/tasks/change-labels-task'
    #   task = new ChangeLabelsTask
    #     threads: threadsOrIds
    #     labelsToAdd: [@category]
    #     labelsToRemove: labelsToRemove
    # else
    #   ChangeFolderTask = require './flux/tasks/change-folder-task'
    #   task = new ChangeFolderTask
    #     threads: threadsOrIds
    #     folder: @category
    #
    # Actions.queueTask(task)


module.exports = MailboxPerspective

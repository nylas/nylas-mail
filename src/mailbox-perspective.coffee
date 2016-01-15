_ = require 'underscore'

AccountStore = require './flux/stores/account-store'
CategoryStore = require './flux/stores/category-store'
DatabaseStore = require './flux/stores/database-store'
SearchSubscription = require './search-subscription'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'
CategoryHelpers = require './category-helpers'
Thread = require './flux/models/thread'
Actions = require './flux/actions'

# This is a class cluster. Subclasses are not for external use!
# https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html

class MailboxPerspective

  # Factory Methods

  @forCategory: (accountIds, category) ->
    new CategoryMailboxPerspective([category])

  @forCategories: (accountIds, categories) ->
    new CategoryMailboxPerspective(categories)

  @forStarred: (accountIds) ->
    new StarredMailboxPerspective(accountIds)

  @forSearch: (accountIds, query) ->
    new SearchMailboxPerspective(accountIds, query)

  @forAll: (accountIds) ->
    new AllMailboxPerspective(accountIds)

  threads: ->
    matchers = [@matchers()]
    matchers.push Thread.attributes.accountId.in(@accountIds) if @accountIds

    query = DatabaseStore.findAll(Thread).where(matchers).limit(0)
    return new MutableQuerySubscription(query, {asResultSet: true})

  # Instance Methods

  constructor: (@accountIds) ->

  isEqual: (other) ->
    return false unless other and @constructor.name is other.constructor.name
    return false unless other.name is @name
    return false unless _.isEqual(@accountIds, other.accountIds)

    matchers = @matchers() ? []
    otherMatchers = other.matchers() ? []
    return false if otherMatchers.length isnt matchers.length

    for idx in [0...matchers.length]
      if matchers[idx].value() isnt otherMatchers[idx].value()
        return false

    true

  categoryId: ->
    throw new Error("categoryId: Not implemented in base class.")

  matchers: ->
    throw new Error("matchers: Not implemented in base class.")

  canApplyToThreads: ->
    throw new Error("canApplyToThreads: Not implemented in base class.")

  applyToThreads: (threadsOrIds) ->
    throw new Error("applyToThreads: Not implemented in base class.")

  # Whether or not the current MailboxPerspective can "archive" or "trash"
  # Subclasses should call `super` if they override these methods
  canArchiveThreads: ->
    for aid in @accountIds
      return false unless CategoryStore.getArchiveCategory(AccountStore.accountForId(aid))
    return true

  canTrashThreads: ->
    for aid in @accountIds
      return false unless CategoryStore.getTrashCategory(AccountStore.accountForId(aid))
    return true

class SearchMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds, @searchQuery) ->
    @

  isEqual: (other) ->
    super(other) and other.searchQuery is @searchQuery

  matchers: ->
    null

  canApplyToThreads: ->
    false

  canArchiveThreads: ->
    false

  canTrashThreads: ->
    false

  categoryIds: ->
    null

  threads: ->
    new SearchSubscription(@searchQuery, @accountIds)

class AllMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds) ->
    @name = "All"
    @iconName = "all-mail.png"
    @

  matchers: ->
    [Thread.attributes.accountId.in(@accountIds)]

  canApplyToThreads: ->
    true

  canArchiveThreads: ->
    false

  canTrashThreads: ->
    false

  categoryIds: ->
    @accountIds.map (aid) ->
      CategoryStore.getStandardCategory(AccountStore.accountForId(aid), "all")?.id


class StarredMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds) ->
    @name = "Starred"
    @iconName = "starred.png"
    @

  matchers: ->
    [Thread.attributes.starred.equal(true)]

  categoryIds: ->
    null

  canApplyToThreads: ->
    true

  applyToThreads: (threadsOrIds) ->
    ChangeStarredTask = require './flux/tasks/change-starred-task'
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true})
    Actions.queueTask(task)


class CategoryMailboxPerspective extends MailboxPerspective
  constructor: (@categories) ->
    unless @categories instanceof Array
      throw new Error("CategoryMailboxPerspective: You must provide a `categories` array")

    @accountIds = _.uniq(_.pluck(@categories, 'accountId'))

    # Note: We pick the display name and icon assuming that you won't create a
    # perspective with Inbox and Sent or anything crazy like that... todo?
    @name = @categories[0].displayName
    if @category[0].name
      @iconName = "#{@category[0].name}.png"
    else
      @iconName = CategoryHelpers.categoryIconName(@accountIds[0])

    @

  matchers: =>
    matchers.push Thread.attributes.labels.containsAny(@categoryIds())
    matchers

  categoryIds: ->
    _.pluck(@categories, 'id')

  canApplyToThreads: ->
    not _.any @categories, (c) -> c.isLockedCategory()

  canArchiveThreads: ->
    for cat in @categories
      return false if cat.name in ["archive", "all", "sent"]
    super

  canTrashThreads: ->
    for cat in @categories
      return false if cat.name in ["trash"]
    super

  applyToThreads: (threadsOrIds) ->
    # TODO:
    # categoryToApplyForAccount = {}
    # for cat in @categories
    #   categoryToApplyForAccount[cat.accountId] = cat
    #
    # @categories.forEach (cat) ->
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

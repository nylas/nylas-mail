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

  @forCategory: (account, category) ->
    new CategoryMailboxPerspective(account, category)

  @forStarred: (account) ->
    new StarredMailboxPerspective(account)

  @forSearch: (account, query) ->
    new SearchMailboxPerspective(account, query)

  @forAll: (account) ->
    new AllMailboxPerspective(account)

  @unified: ->
    new UnifiedMailboxPerspective()

  threads: ->
    matchers = []
    if @account
      matchers.push Thread.attributes.accountId.equal(@account.id)
    matchers = matchers.concat(@matchers())
    query = DatabaseStore.findAll(Thread).where(matchers).limit(0)
    return new MutableQuerySubscription(query, {asResultSet: true})

  # Instance Methods

  constructor: (@account) ->

  hasSameAccount: (other) ->
    return true if (@account ? null) is (other.account ? null)
    return @account?.id is other?.account?.id

  isEqual: (other) ->
    return false unless other and @constructor.name is other.constructor.name
    return false if other.name isnt @name
    return false unless @hasSameAccount(other)

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
    return false unless CategoryStore.getArchiveCategory(@account)
    return true

  canTrashThreads: ->
    return false unless CategoryStore.getTrashCategory(@account)
    return true

class SearchMailboxPerspective extends MailboxPerspective
  constructor: (@account, @searchQuery) ->
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

  categoryId: ->
    null

  threads: ->
    new SearchSubscription(@searchQuery, @account?.id)

class AllMailboxPerspective extends MailboxPerspective
  constructor: (@account) ->
    @name = "All"
    @iconName = "all-mail.png"
    @

  matchers: ->
    [Thread.attributes.accountId.equal(@account.id)]

  canApplyToThreads: ->
    true

  canArchiveThreads: ->
    false

  canTrashThreads: ->
    false

  categoryId: ->
    CategoryStore.getStandardCategory(@account, "all")?.id


class StarredMailboxPerspective extends MailboxPerspective
  constructor: (@account) ->
    @name = "Starred"
    @iconName = "starred.png"
    @

  matchers: ->
    [Thread.attributes.starred.equal(true)]

  categoryId: ->
    null

  canApplyToThreads: ->
    true

  applyToThreads: (threadsOrIds) ->
    ChangeStarredTask = require './flux/tasks/change-starred-task'
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true})
    Actions.queueTask(task)


class CategoryMailboxPerspective extends MailboxPerspective
  constructor: (@account, @category) ->
    unless @category
      throw new Error("CategoryMailboxPerspective: You msut provide a category")

    @name = @category.displayName

    if @category.name
      @iconName = "#{@category.name}.png"
    else
      @iconName = CategoryHelpers.categoryIconName(@account)

    @

  matchers: =>
    matchers = []
    return matchers unless @account?
    if @account.usesLabels()
      matchers.push Thread.attributes.labels.contains(@category.id)
    else if @account.usesFolders()
      matchers.push Thread.attributes.folders.contains(@category.id)
    matchers

  categoryId: ->
    @category.id

  canApplyToThreads: ->
    not (@category.isLockedCategory())

  canArchiveThreads: ->
    return false if @category.name in ["archive", "all", "sent"]
    super

  canTrashThreads: ->
    return false if @category.name in ["trash"]
    super

  applyToThreads: (threadsOrIds) ->
    if @account.usesLabels()
      FocusedPerspectiveStore = require './flux/stores/focused-perspective-store'
      currentLabel = FocusedPerspectiveStore.current().category
      if currentLabel and not (currentLabel.isLockedCategory())
        labelsToRemove = [currentLabel]

      ChangeLabelsTask = require './flux/tasks/change-labels-task'
      task = new ChangeLabelsTask
        threads: threadsOrIds
        labelsToAdd: [@category]
        labelsToRemove: labelsToRemove
    else
      ChangeFolderTask = require './flux/tasks/change-folder-task'
      task = new ChangeFolderTask
        threads: threadsOrIds
        folder: @category

    Actions.queueTask(task)

class UnifiedMailboxPerspective extends MailboxPerspective

  categoryId: ->
    null

  matchers: ->
    []

  canApplyToThreads: ->
    false

module.exports = MailboxPerspective

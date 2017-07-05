_ = require 'underscore'

Utils = require './flux/models/utils'
TaskFactory = require('./flux/tasks/task-factory').default
AccountStore = require('./flux/stores/account-store').default
CategoryStore = require './flux/stores/category-store'
DatabaseStore = require('./flux/stores/database-store').default
OutboxStore = require('./flux/stores/outbox-store').default
ThreadCountsStore = require './flux/stores/thread-counts-store'
RecentlyReadStore = require('./flux/stores/recently-read-store').default
FolderSyncProgressStore = require('./flux/stores/folder-sync-progress-store').default
MutableQuerySubscription = require('./flux/models/mutable-query-subscription').default
UnreadQuerySubscription = require('./flux/models/unread-query-subscription').default
Matcher = require('./flux/attributes/matcher').default
Thread = require('./flux/models/thread').default
Category = require('./flux/models/category').default
Label = require('./flux/models/label').default
Folder = require('./flux/models/folder').default
Actions = require('./flux/actions').default

ChangeLabelsTask = require('./flux/tasks/change-labels-task').default
ChangeFolderTask = require('./flux/tasks/change-folder-task').default
ChangeUnreadTask = require('./flux/tasks/change-unread-task').default

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
    # TODO this method is broken
    categories = CategoryStore.getCategoriesWithRoles(accountsOrIds, names...)
    @forCategories(categories)

  @forStarred: (accountsOrIds) ->
    new StarredMailboxPerspective(accountsOrIds)

  @forUnread: (categories) ->
    return @forNothing() if categories.length is 0
    new UnreadMailboxPerspective(categories)

  @forInbox: (accountsOrIds) =>
    @forStandardCategories(accountsOrIds, 'inbox')

  @fromJSON: (json) =>
    try
      if json.type is CategoryMailboxPerspective.name
        categories = JSON.parse(json.serializedCategories, Utils.registeredObjectReviver)
        return @forCategories(categories)
      else if json.type is UnreadMailboxPerspective.name
        categories = JSON.parse(json.serializedCategories, Utils.registeredObjectReviver)
        return @forUnread(categories)
      else if json.type is StarredMailboxPerspective.name
        return @forStarred(json.accountIds)
      else if json.type is DraftsMailboxPerspective.name
        return @forDrafts(json.accountIds)
      else
        return @forInbox(json.accountIds)
    catch error
      NylasEnv.reportError(new Error("Could not restore mailbox perspective: #{error}"))
      return null

  # Instance Methods

  constructor: (@accountIds) ->
    unless @accountIds instanceof Array and _.every(@accountIds, (aid) =>
      (typeof aid is 'string') or (typeof aid is 'number')
    )
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
    @categoriesSharedRole() is 'inbox'

  isSent: =>
    @categoriesSharedRole() is 'sent'

  isTrash: =>
    @categoriesSharedRole() is 'trash'

  isArchive: =>
    false

  emptyMessage: =>
    "No Messages"

  categories: =>
    []

  # overwritten in CategoryMailboxPerspective
  hasSyncingCategories: =>
    false

  categoriesSharedRole: =>
    @_categoriesSharedRole ?= Category.categoriesSharedRole(@categories())
    @_categoriesSharedRole

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
    return false if @isArchive()
    accounts = AccountStore.accountsForItems(threads)
    return _.every(accounts, (acc) -> acc.canArchiveThreads())

  canTrashThreads: (threads) =>
    @canMoveThreadsTo(threads, 'trash')

  canMoveThreadsTo: (threads, standardCategoryName) =>
    return false if @categoriesSharedRole() is standardCategoryName
    return _.every AccountStore.accountsForItems(threads), (acc) ->
      CategoryStore.getCategoryByRole(acc, standardCategoryName)?

  tasksForRemovingItems: (threads) =>
    if not threads instanceof Array
      throw new Error("tasksForRemovingItems: you must pass an array of threads or thread ids")
    []


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
      Thread.attributes.starred.equal(true),
      Thread.attributes.inAllMail.equal(true),
    ]).limit(0)

    # Adding a "account_id IN (a,b,c)" clause to our query can result in a full
    # table scan. Don't add the where clause if we know we want results from all.
    if @accountIds.length < AccountStore.accounts().length
      query.where(Thread.attributes.accountId.in(@accountIds))

    return new MutableQuerySubscription(query, {emitResultSet: true})

  canReceiveThreadsFromAccountIds: =>
    super

  receiveThreads: (threadsOrIds) =>
    ChangeStarredTask = require('./flux/tasks/change-starred-task').default
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true, source: "Dragged Into List"})
    Actions.queueTask(task)

  tasksForRemovingItems: (threads) =>
    task = TaskFactory.taskForInvertingStarred({
      threads: threads
      source: "Removed From List"
    })
    return [task]


class EmptyMailboxPerspective extends MailboxPerspective
  constructor: ->
    @accountIds = []

  threads: =>
    # We need a Thread query that will not return any results and take no time.
    # We use lastMessageReceivedTimestamp because it is the first column on an
    # index so this returns zero items nearly instantly. In the future, we might
    # want to make a Query.forNothing() to go along with MailboxPerspective.forNothing()
    query = DatabaseStore.findAll(Thread).where(lastMessageReceivedTimestamp: -1).limit(0)
    return new MutableQuerySubscription(query, {emitResultSet: true})

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
    if @_categories[0].role
      @iconName = "#{@_categories[0].role}.png"
    else
      @iconName = if @_categories[0] instanceof Label then "label.png" else "folder.png"
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

    unless @categoriesSharedRole() in ['spam', 'trash']
      query.where(inAllMail: true)

    if @_categories.length > 1 and @accountIds.length < @_categories.length
      # The user has multiple categories in the same account selected, which
      # means our result set could contain multiple copies of the same threads
      # (since we do an inner join) and we need SELECT DISTINCT. Note that this
      # can be /much/ slower and we shouldn't do it if we know we don't need it.
      query.distinct()

    return new MutableQuerySubscription(query, {emitResultSet: true})

  unreadCount: =>
    sum = 0
    for cat in @_categories
      sum += ThreadCountsStore.unreadCountForCategoryId(cat.id)
    sum

  categories: =>
    @_categories

  hasSyncingCategories: =>
    not @_categories.every (cat) =>
      representedFolder = cat instanceof Folder ? cat : CategoryStore.getAllMailCategory(cat.accountId)
      return FolderSyncProgressStore.isSyncCompleteForAccount(cat.accountId, representedFolder.path)

  isArchive: =>
    _.every(@_categories, (cat) -> cat.isArchive())

  canReceiveThreadsFromAccountIds: =>
    super and not _.any @_categories, (c) -> c.isLockedCategory()

  receiveThreads: (threadsOrIds) =>
    FocusedPerspectiveStore = require('./flux/stores/focused-perspective-store').default
    current = FocusedPerspectiveStore.current()

    # This assumes that the we don't have more than one category per accountId
    # attached to this perspective
    DatabaseStore.modelify(Thread, threadsOrIds).then (threads) =>
      tasks = TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) =>
        if current.categoriesSharedRole() in Category.LockedCategoryNames
          return null
        
        myCat = @categories().find((c) -> c.accountId == accountId)
        currentCat = current.categories().find((c) -> c.accountId == accountId)

        if myCat instanceof Folder
          # folder/label to folder
          return new ChangeFolderTask({
            threads: accountThreads,
            source: "Dragged into list",
            folder: myCat,
          })
        else if myCat instanceof Label and currentCat instanceof Folder
          # folder to label
          # dragging from trash or spam into a label? We need to both apply the label and move.
          return [
            new ChangeFolderTask({
              threads: accountThreads,
              source: "Dragged into list",
              folder: CategoryStore.getCategoryByRole(accountId, 'all'),
            }),
            new ChangeLabelsTask({
              threads: accountThreads,
              source: "Dragged into list",
              labelsToAdd: [myCat],
            })
          ]
        else
          # label to label
          return [
            new ChangeLabelsTask({
              threads: accountThreads,
              source: "Dragged into list",
              labelsToAdd: [myCat],
              labelsToRemove: [currentCat],
            })
          ]
      )
      Actions.queueTasks(tasks)

  # Public:
  # Returns the tasks for removing threads from this perspective and moving them
  # to the default destination based on the current view:
  #
  # if you're looking at a folder:
  # - spam: null
  # - trash: null
  # - archive: trash
  # - all others: "finished category (archive or trash)"

  # if you're looking at a label
  # - if finished category === "archive" remove the label
  # - if finished category === "trash" move to trash folder, keep labels intact
  #
  tasksForRemovingItems: (threads, source = "Removed from list") =>
    # TODO this is an awful hack
    if @isArchive()
      role = 'archive'
    else
      role = @categoriesSharedRole()
      'archive'

    if role == 'spam' or role == 'trash'
      return []
    
    if role == 'archive'
      return TaskFactory.tasksForMovingToTrash({threads, source})
    
    return TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) =>
      acct = AccountStore.accountForId(accountId)
      preferred = acct.preferredRemovalDestination()
      cat = @categories().find((c) -> c.accountId == accountId)
      if cat instanceof Label and preferred.role != 'trash'
        inboxCat = CategoryStore.getInboxCategory(accountId)
        return new ChangeLabelsTask({
          threads: accountThreads,
          labelsToRemove: [cat, inboxCat],
          source: source,
        })
      else 
        return new ChangeFolderTask({
          threads: accountThreads,
          folder: preferred,
          source: source,
        })
    )


class UnreadMailboxPerspective extends CategoryMailboxPerspective
  constructor: (categories) ->
    super(categories)
    @name = "Unread"
    @iconName = "unread.png"
    @

  threads: =>
    return new UnreadQuerySubscription(_.pluck(@categories(), 'id'))

  unreadCount: =>
    0

  receiveThreads: (threadsOrIds) =>
    super(threadsOrIds)

    ChangeUnreadTask ?= require('./flux/tasks/change-unread-task').default
    task = new ChangeUnreadTask({threads:threadsOrIds, unread: true, source: "Dragged Into List"})
    Actions.queueTask(task)

  tasksForRemovingItems: (threads, ruleset, source) =>
    ChangeUnreadTask ?= require('./flux/tasks/change-unread-task').default
    tasks = super(threads, ruleset)
    tasks.push new ChangeUnreadTask({threads, unread: false, source: source || "Removed From List"})
    return tasks


module.exports = MailboxPerspective

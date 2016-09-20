_ = require 'underscore'
_str = require 'underscore.string'
{WorkspaceStore,
 MailboxPerspective,
 FocusedPerspectiveStore,
 SyncbackCategoryTask,
 DestroyCategoryTask,
 CategoryStore,
 Actions,
 Utils,
 RegExpUtils} = require 'nylas-exports'
{OutlineViewItem} = require 'nylas-component-kit'

SidebarActions = require './sidebar-actions'

idForCategories = (categories) ->
  _.pluck(categories, 'id').join('-')

countForItem = (perspective) ->
  unreadCountEnabled = NylasEnv.config.get('core.workspace.showUnreadForAllCategories')
  if perspective.isInbox() or unreadCountEnabled
    return perspective.unreadCount()
  return 0

isItemSelected = (perspective) ->
  (WorkspaceStore.rootSheet() in [WorkspaceStore.Sheet.Threads, WorkspaceStore.Sheet.Drafts] and
    FocusedPerspectiveStore.current().isEqual(perspective))

isItemCollapsed = (id) ->
  if NylasEnv.savedState.sidebarKeysCollapsed[id] isnt undefined
    NylasEnv.savedState.sidebarKeysCollapsed[id]
  else
    true

toggleItemCollapsed = (item) ->
  return unless item.children.length > 0
  SidebarActions.setKeyCollapsed(item.id, not isItemCollapsed(item.id))

onDeleteItem = (item) ->
  # TODO Delete multiple categories at once
  return if item.deleted is true
  category = item.perspective.category()
  return unless category

  Actions.queueTask(new DestroyCategoryTask({category}))

onEditItem = (item, value) ->
  return unless value
  return if item.deleted is true
  category = item.perspective.category()
  return unless category
  re = RegExpUtils.subcategorySplitRegex()
  match = re.exec(category.displayName)
  lastMatch = match
  while match
    lastMatch = match
    match = re.exec(category.displayName)
  if lastMatch
    newDisplayName = category.displayName.slice(0, lastMatch.index + 1) + value
  else
    newDisplayName = value
  if newDisplayName is category.displayName
    return
  Actions.queueTask(new SyncbackCategoryTask({category, displayName: newDisplayName}))


class SidebarItem

  @forPerspective: (id, perspective, opts = {}) ->
    counterStyle = OutlineViewItem.CounterStyles.Alt if perspective.isInbox()

    return _.extend({
      id: id
      name: perspective.name
      contextMenuLabel: perspective.name
      count: countForItem(perspective)
      iconName: perspective.iconName
      children: []
      perspective: perspective
      selected: isItemSelected(perspective)
      collapsed: isItemCollapsed(id) ? true
      counterStyle: counterStyle
      onDelete: if opts.deletable then onDeleteItem else undefined
      onEdited: if opts.editable then onEditItem else undefined
      onCollapseToggled: toggleItemCollapsed

      onDrop: (item, event) ->
        jsonString = event.dataTransfer.getData('nylas-threads-data')
        jsonData = null
        try
          jsonData = JSON.parse(jsonString)
        catch err
          console.error("JSON parse error: #{err}")
        return unless jsonData
        item.perspective.receiveThreads(jsonData.threadIds)

      shouldAcceptDrop: (item, event) ->
        target = item.perspective
        current = FocusedPerspectiveStore.current()
        return false unless event.dataTransfer.types.includes('nylas-threads-data')
        return false if target.isEqual(current)

        # We can't inspect the drag payload until drop, so we use a dataTransfer
        # type to encode the account IDs of threads currently being dragged.
        accountsType = event.dataTransfer.types.find((t) => t.startsWith('nylas-accounts='))
        accountIds = (accountsType || "").replace('nylas-accounts=', '').split(',')
        return target.canReceiveThreadsFromAccountIds(accountIds)

      onSelect: (item) ->
        Actions.focusMailboxPerspective(item.perspective)
    }, opts)


  @forCategories: (categories = [], opts = {}) ->
    id = idForCategories(categories)
    contextMenuLabel = _str.capitalize(categories[0]?.displayType())
    perspective = MailboxPerspective.forCategories(categories)

    opts.deletable ?= true
    opts.editable ?= true
    opts.contextMenuLabel = contextMenuLabel
    @forPerspective(id, perspective, opts)

  @forSnoozed: (accountIds, opts = {}) ->
    # TODO This constant should be available elsewhere
    constants = require('../../thread-snooze/lib/snooze-constants')
    displayName = constants.SNOOZE_CATEGORY_NAME
    id = displayName
    id += "-#{opts.name}" if opts.name
    opts.name = "Snoozed" unless opts.name
    opts.iconName= 'snooze.png'

    categories = accountIds.map (accId) =>
      _.findWhere CategoryStore.categories(accId), {displayName}
    categories = _.compact(categories)

    perspective = MailboxPerspective.forCategories(categories)
    perspective.name = id unless perspective.name
    @forPerspective(id, perspective, opts)

  @forStarred: (accountIds, opts = {}) ->
    perspective = MailboxPerspective.forStarred(accountIds)
    id = 'Starred'
    id += "-#{opts.name}" if opts.name
    @forPerspective(id, perspective, opts)

  @forUnread: (accountIds, opts = {}) ->
    categories = accountIds.map (accId) =>
      CategoryStore.getStandardCategory(accId, 'inbox')

    # NOTE: It's possible for an account to not yet have an `inbox`
    # category. Since the `SidebarStore` triggers on `AccountStore`
    # changes, it'll trigger the exact moment an account is added to the
    # config. However, the API has not yet come back with the list of
    # `categories` for that account.
    categories = _.compact(categories)

    perspective = MailboxPerspective.forUnread(categories)
    id = 'Unread'
    id += "-#{opts.name}" if opts.name
    @forPerspective(id, perspective, opts)

  @forDrafts: (accountIds, opts = {}) ->
    perspective = MailboxPerspective.forDrafts(accountIds)
    id = "Drafts-#{opts.name}"
    @forPerspective(id, perspective, opts)

module.exports = SidebarItem

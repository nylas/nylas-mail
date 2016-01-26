_ = require 'underscore'
{WorkspaceStore,
 MailboxPerspective,
 FocusedPerspectiveStore,
 DestroyCategoryTask,
 Actions} = require 'nylas-exports'
{OutlineViewItem} = require 'nylas-component-kit'


idForCategories = (categories) ->
  categories.map((cat) -> cat.id).join('-')

countForItem = (perspective) ->
  unreadCountEnabled = NylasEnv.config.get('core.workspace.showUnreadForAllCategories')
  if perspective.isInbox() or unreadCountEnabled
    return perspective.threadUnreadCount()
  return 0

isItemSelected = (perspective) ->
  (WorkspaceStore.rootSheet() in [WorkspaceStore.Sheet.Threads, WorkspaceStore.Sheet.Drafts] and
    FocusedPerspectiveStore.current().isEqual(perspective))

isItemDeleted = (perspective) ->
  _.any perspective.categories(), (c) -> c.isDeleted

isItemCollapsed = (id) ->
  key = "core.accountSidebarCollapsed.#{id}"
  NylasEnv.config.get(key)

toggleItemCollapsed = (item) ->
  return unless item.children.length > 0
  key = "core.accountSidebarCollapsed.#{item.id}"
  NylasEnv.config.set(key, not item.collapsed)


class SidebarItem

  @forPerspective: (id, perspective, opts = {}) ->
    counterStyle = OutlineViewItem.CounterStyles.Alt if perspective.isInbox()

    if opts.deletable
      onDeleteItem = (item) ->
        # TODO Delete multiple categories at once
        return if item.perspective.categories.length > 1
        return if item.deleted is true
        category = item.perspective.categories[0]
        Actions.queueTask(new DestroyCategoryTask({category: category}))

    return _.extend({
      id: id
      name: perspective.name
      count: countForItem(perspective)
      iconName: perspective.iconName
      children: []
      perspective: perspective
      selected: isItemSelected(perspective)
      collapsed: isItemCollapsed(id) ? true
      deleted: isItemDeleted(perspective)
      counterStyle: counterStyle
      dataTransferType: 'nylas-thread-ids'
      onDelete: onDeleteItem
      onToggleCollapsed: toggleItemCollapsed
      onDrop: (item, ids) ->
        return unless ids
        item.perspective.applyToThreads(ids)
      shouldAcceptDrop: (item, event) ->
        perspective = item.perspective
        return false unless perspective
        return false if perspective.isEqual(FocusedPerspectiveStore.current())
        return false unless perspective.canApplyToThreads()
        item.dataTransferType in event.dataTransfer.types
      onSelect: (item) ->
        Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
        Actions.focusMailboxPerspective(item.perspective)
    }, opts)


  @forCategories: (categories = [], opts = {}) ->
    id = idForCategories(categories)
    perspective = MailboxPerspective.forCategories(categories)
    @forPerspective(id, perspective, opts)

  @forStarred: (accountIds, opts = {}) ->
    perspective = MailboxPerspective.forStarred(accountIds)
    id = 'Starred'
    id += "-#{opts.name}" if opts.name
    @forPerspective(id, perspective, opts)

  @forDrafts: (accountIds, opts = {}) ->
    perspective = MailboxPerspective.forDrafts(accountIds)
    id = "Drafts-#{opts.name}"
    opts.onSelect = ->
      Actions.focusMailboxPerspective(perspective)
      Actions.selectRootSheet(WorkspaceStore.Sheet.Drafts)
    @forPerspective(id, perspective, opts)

module.exports = SidebarItem

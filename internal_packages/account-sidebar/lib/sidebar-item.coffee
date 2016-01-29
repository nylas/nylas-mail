_ = require 'underscore'
{WorkspaceStore,
 MailboxPerspective,
 FocusedPerspectiveStore,
 SyncbackCategoryTask,
 DestroyCategoryTask,
 Actions,
 Utils} = require 'nylas-exports'
{OutlineViewItem} = require 'nylas-component-kit'


idForCategories = (categories) ->
  _.pluck(categories, 'id').join('-')

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
  Actions.queueTask(new SyncbackCategoryTask({category, displayName: value}))


class SidebarItem

  @forPerspective: (id, perspective, opts = {}) ->
    counterStyle = OutlineViewItem.CounterStyles.Alt if perspective.isInbox()

    return _.extend({
      id: id
      name: perspective.name
      count: countForItem(perspective)
      iconName: perspective.iconName
      children: []
      perspective: perspective
      className: if isItemDeleted(perspective) then 'deleted' else ''
      selected: isItemSelected(perspective)
      collapsed: isItemCollapsed(id) ? true
      counterStyle: counterStyle
      dataTransferType: 'nylas-threads-data'
      onDelete: if opts.deletable then onDeleteItem else undefined
      onEdited: if opts.editable then onEditItem else undefined
      onToggleCollapsed: toggleItemCollapsed
      onDrop: (item, event) ->
        jsonString = event.dataTransfer.getData(item.dataTransferType)
        data = Utils.jsonParse(jsonString)
        return unless data
        item.perspective.receiveThreads(data.threadIds)
      shouldAcceptDrop: (item, event) ->
        target = item.perspective
        current = FocusedPerspectiveStore.current()
        jsonString = event.dataTransfer.getData(item.dataTransferType)
        data = Utils.jsonParse(jsonString)
        return false unless data
        return false unless target
        return false if target.isEqual(current)
        return false unless target.canReceiveThreads(data.accountIds)

        return item.dataTransferType in event.dataTransfer.types

      onSelect: (item) ->
        Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
        Actions.focusMailboxPerspective(item.perspective)
    }, opts)


  @forCategories: (categories = [], opts = {}) ->
    id = idForCategories(categories)
    perspective = MailboxPerspective.forCategories(categories)
    opts.deletable ?= true
    opts.editable ?= true
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

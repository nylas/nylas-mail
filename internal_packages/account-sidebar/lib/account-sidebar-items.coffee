{WorkspaceStore,
 FocusedPerspectiveStore,
 ThreadCountsStore,
 DraftCountStore,
 DestroyCategoryTask,
 Actions} = require 'nylas-exports'
AccountSidebarActions = require './account-sidebar-actions'


class MailboxPerspectiveSidebarItem

  constructor: (@mailboxPerspective, @shortenedName, @children = []) ->
    @category = @mailboxPerspective.category()

    @id = @category?.id ? @mailboxPerspective.name
    @name = @shortenedName ? @mailboxPerspective.name
    @iconName = @mailboxPerspective.iconName
    @count = @_count()
    @dataTransferType = 'nylas-thread-ids'
    @useAltCountStyle = true if @category?.name is 'inbox'

    @isSelected = @_isSelected()
    @isCollapsed = @_isCollapsed()
    @isDeleted = @category?.isDeleted is true

  _count: =>
    unreadCountEnabled = NylasEnv.config.get('core.workspace.showUnreadForAllCategories')
    if @category and (@category.name is 'inbox' or unreadCountEnabled)
      return ThreadCountsStore.unreadCountForCategoryId(@category.id)
    return 0

  _isSelected: ->
    if WorkspaceStore.rootSheet() is WorkspaceStore.Sheet.Threads
      current = FocusedPerspectiveStore.current()
      return (
        @id is current?.category()?.id or
        @id is current?.name
      )

  _isCollapsed: =>
    key = "core.accountSidebarCollapsed.#{@id}"
    NylasEnv.config.get(key)

  onToggleCollapsed: =>
    return unless @children.length > 0
    key = "core.accountSidebarCollapsed.#{@id}"
    @isCollapsed = not @_isCollapsed()
    NylasEnv.config.set(key, @isCollapsed)

  onDelete: =>
    return if @category?.isDeleted is true
    Actions.queueTask(new DestroyCategoryTask({category: @category}))

  onDrop: (ids) =>
    return unless ids
    @mailboxPerspective.applyToThreads(ids)

  shouldAcceptDrop: (event) =>
    perspective = @mailboxPerspective
    return false unless perspective
    return false if perspective.isEqual(FocusedPerspectiveStore.current())
    return false unless perspective.canApplyToThreads()
    @dataTransferType in event.dataTransfer.types

  onSelect: =>
    Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.focusMailboxPerspective(@mailboxPerspective)
    AccountSidebarActions.selectItem()


class SheetSidebarItem

  constructor: (@name, @iconName, @sheet, @count) ->
    @id = @sheet?.id ? @name
    @isSelected = WorkspaceStore.rootSheet().id is @id

  onSelect: =>
    Actions.selectRootSheet(@sheet)
    AccountSidebarActions.selectItem()


class DraftListSidebarItem extends SheetSidebarItem

  constructor: ->
    super
    @count = DraftCountStore.count()


module.exports = {
  MailboxPerspectiveSidebarItem
  SheetSidebarItem
  DraftListSidebarItem
}

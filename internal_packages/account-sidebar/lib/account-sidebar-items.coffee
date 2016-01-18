{WorkspaceStore,
 FocusedPerspectiveStore,
 ThreadCountsStore,
 DraftCountStore,
 DestroyCategoryTask,
 Actions} = require 'nylas-exports'
_ = require 'underscore'
{OutlineViewItem} = require 'nylas-component-kit'


class MailboxPerspectiveSidebarItem

  constructor: (@mailboxPerspective, @shortenedName, @children = []) ->
    category = @mailboxPerspective.categories()[0]

    @id = category?.id ? @mailboxPerspective.name
    @name = @shortenedName ? @mailboxPerspective.name
    @iconName = @mailboxPerspective.iconName
    @dataTransferType = 'nylas-thread-ids'
    @counterStyle = OutlineViewItem.CounterStyles.Alt if @mailboxPerspective.isInbox()

    # Sidenote: I think treating the sidebar items as dumb bundles of data is a
    # good idea. `count` /shouldn't/ be a function since if it's value changes,
    # it wouldn't trigger a refresh or anything. It'd just be confusing if it
    # could change. But making these all classes makes it feel like you should
    # call these methods externally.
    #
    # Might be good to make a factory that returns OutlineViewItemModels instead
    # of having classes here. eg: AccountSidebar.itemForPerspective(p) returns
    #    { count: X, isSelected: false, isDeleted: true}...
    #
    @count = @_count()
    @selected = @_isSelected()
    @deleted = @_isDeleted()
    @collapsed = @_isCollapsed()

    @

  _count: =>
    unreadCountEnabled = NylasEnv.config.get('core.workspace.showUnreadForAllCategories')
    if @mailboxPerspective.isInbox() or unreadCountEnabled
      return @mailboxPerspective.threadUnreadCount()
    return 0

  _isSelected: =>
    (WorkspaceStore.rootSheet() is WorkspaceStore.Sheet.Threads and
     FocusedPerspectiveStore.current().isEqual(@mailboxPerspective))

  _isDeleted: =>
    _.any @mailboxPerspective.categories(), (c) -> c.isDeleted

  _isCollapsed: =>
    key = "core.accountSidebarCollapsed.#{@id}"
    NylasEnv.config.get(key)

  onToggleCollapsed: =>
    return unless @children.length > 0
    key = "core.accountSidebarCollapsed.#{@id}"
    @collapsed = not @_isCollapsed()
    NylasEnv.config.set(key, @collapsed)

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


class SheetSidebarItem

  constructor: (@name, @iconName, @sheet) ->
    @id = @sheet?.id ? @name
    @selected = WorkspaceStore.rootSheet().id is @id

  onSelect: =>
    Actions.selectRootSheet(@sheet)


class DraftListSidebarItem extends SheetSidebarItem

  constructor: ->
    super

  count: ->
    DraftCountStore.count()


module.exports = {
  MailboxPerspectiveSidebarItem
  SheetSidebarItem
  DraftListSidebarItem
}

_ = require 'underscore'
React = require 'react'

{Utils,
 Label,
 Folder,
 Thread,
 Actions,
 TaskQueue,
 TaskFactory,
 AccountStore,
 CategoryStore,
 DatabaseStore,
 WorkspaceStore,
 SyncbackCategoryTask,
 TaskQueueStatusStore,
 FocusedMailViewStore} = require 'nylas-exports'

{Menu,
 Popover,
 RetinaImg,
 LabelColorizer} = require 'nylas-component-kit'

# This changes the category on one or more threads.
class CategoryPicker extends React.Component
  @displayName: "CategoryPicker"
  @containerRequired: false

  constructor: (@props) ->
    @state = _.extend @_recalculateState(@props), searchValue: ""

  @contextTypes:
    sheetDepth: React.PropTypes.number

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push CategoryStore.listen @_onStoreChanged
    @unsubscribers.push AccountStore.listen @_onStoreChanged

    @_commandUnsubscriber = atom.commands.add 'body',
      "application:change-category": @_onOpenCategoryPopover

    # If the threads we're picking categories for change, (like when they
    # get their categories updated), we expect our parents to pass us new
    # props. We don't listen to the DatabaseStore ourselves.

  componentWillReceiveProps: (nextProps) ->
    @setState @_recalculateState(nextProps)

  componentWillUnmount: =>
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers
    @_commandUnsubscriber.dispose()

  render: =>
    return <span></span> unless @_account

    if @_account?.usesLabels()
      img = "ic-toolbar-tag.png"
      tooltip = "Apply Labels"
      placeholder = "Label as"
    else if @_account?.usesFolders()
      img = "ic-toolbar-movetofolder.png"
      tooltip = "Move to Folder"
      placeholder = "Move to folder"
    else
      img = ""
      tooltip = ""
      placeholder = ""

    if @state.isPopoverOpen then tooltip = ""

    button = <button className="btn btn-toolbar" data-tooltip={tooltip}>
      <RetinaImg name={img} mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

    headerComponents = [
      <input type="text"
             tabIndex="1"
             key="textfield"
             className="search"
             placeholder={placeholder}
             value={@state.searchValue}
             onChange={@_onSearchValueChange}/>
    ]

    <Popover className="category-picker"
             ref="popover"
             onOpened={@_onPopoverOpened}
             onClosed={@_onPopoverClosed}
             direction="down-align-left"
             style={order: -103}
             buttonComponent={button}>
      <Menu ref="menu"
            headerComponents={headerComponents}
            footerComponents={[]}
            items={@state.categoryData}
            itemKey={ (item) -> item.id }
            itemContent={@_renderItemContent}
            onSelect={@_onSelectCategory}
            defaultSelectedIndex={if @state.searchValue is "" then -1 else 0}
            />
    </Popover>

  _onOpenCategoryPopover: =>
    return unless @_threads().length > 0
    return unless @context.sheetDepth is WorkspaceStore.sheetStack().length - 1
    @refs.popover.open()
    return

  _renderItemContent: (item) =>
    if item.divider
      return <Menu.Item key={item.id} divider={item.divider} />
    else if item.newCategoryItem
      return @_renderCreateNewItem(item)

    if @_account?.usesLabels()
      icon = @_renderCheckbox(item)
    else if @_account?.usesFolders()
      icon = @_renderFolderIcon(item)
    else return <span></span>

    <div className="category-item">
      {icon}
      <div className="category-display-name">
        {@_renderBoldedSearchResults(item)}
      </div>
    </div>

  _renderCreateNewItem: ({searchValue, name}) =>
    if @_account?.usesLabels()
      picName = "tag"
    else if @_account?.usesFolders()
      picName = "folder"

    <div className="category-item category-create-new">
      <RetinaImg className={"category-create-new-#{picName}"}
                 name={"#{picName}.png"}
                 mode={RetinaImg.Mode.ContentIsMask} />
      <div className="category-display-name">
        <strong>&ldquo;{searchValue}&rdquo;</strong> (create new)
      </div>
    </div>

  _renderCheckbox: (item) ->
    styles = {}
    styles.backgroundColor = item.backgroundColor

    if item.usage is 0
      checkStatus = <span></span>
    else if item.usage < item.numThreads
      checkStatus = <RetinaImg
        className="check-img dash"
        name="tagging-conflicted.png"
        mode={RetinaImg.Mode.ContentPreserve}
        onClick={=> @_onSelectCategory(item)}/>
    else
      checkStatus = <RetinaImg
        className="check-img check"
        name="tagging-checkmark.png"
        mode={RetinaImg.Mode.ContentPreserve}
        onClick={=> @_onSelectCategory(item)}/>

    <div className="check-wrap" style={styles}>
      <RetinaImg
        className="check-img check"
        name="tagging-checkbox.png"
        mode={RetinaImg.Mode.ContentPreserve}
        onClick={=> @_onSelectCategory(item)}/>
      {checkStatus}
    </div>

  _renderFolderIcon: (item) ->
    <RetinaImg name={"#{item.name}.png"} fallback={'folder.png'} mode={RetinaImg.Mode.ContentIsMask} />

  _renderBoldedSearchResults: (item) ->
    name = item.display_name
    searchTerm = (@state.searchValue ? "").trim()

    return name if searchTerm.length is 0

    re = Utils.wordSearchRegExp(searchTerm)
    parts = name.split(re).map (part) ->
      # The wordSearchRegExp looks for a leading non-word character to
      # deterine if it's a valid place to search. As such, we need to not
      # include that leading character as part of our match.
      if re.test(part)
        if /\W/.test(part[0])
          return <span>{part[0]}<strong>{part[1..-1]}</strong></span>
        else
          return <strong>{part}</strong>
      else return part
    return <span>{parts}</span>

  _onSelectCategory: (item) =>
    threads = @_threads()

    return unless threads.length > 0
    return unless @_account
    @refs.menu.setSelectedItem(null)

    if item.newCategoryItem
      category = new AccountStore.current().categoryClass()
        displayName: @state.searchValue,
        accountId: AccountStore.current().id
      syncbackTask = new SyncbackCategoryTask({category})
      TaskQueueStatusStore.waitForPerformRemote(syncbackTask).then =>
        DatabaseStore.findBy(category.constructor, clientId: category.clientId).then (category) =>
          applyTask = TaskFactory.taskForApplyingCategory
            threads: threads
            category: category
          Actions.queueTask(applyTask)
      Actions.queueTask(syncbackTask)

    else if item.usage is threads.length
      applyTask = TaskFactory.taskForRemovingCategory
        threads: threads
        category: item.category
      Actions.queueTask(applyTask)

    else
      applyTask = TaskFactory.taskForApplyingCategory
        threads: threads
        category: item.category
      Actions.queueTask(applyTask)

    @refs.popover.close()

  _onStoreChanged: =>
    @setState @_recalculateState(@props)

  _onSearchValueChange: (event) =>
    @setState @_recalculateState(@props, searchValue: event.target.value)

  _onPopoverOpened: =>
    @setState @_recalculateState(@props, searchValue: "")
    @setState isPopoverOpen: true

  _onPopoverClosed: =>
    @setState isPopoverOpen: false

  _recalculateState: (props=@props, {searchValue}={}) =>
    searchValue = searchValue ? @state?.searchValue ? ""
    numThreads = @_threads(props).length
    if numThreads is 0
      return {categoryData: [], searchValue}

    @_account = AccountStore.current()
    return unless @_account

    categories = CategoryStore.getStandardCategories()
      .concat([{divider: true, id: "category-divider"}])
      .concat(CategoryStore.getUserCategories())

    usageCount = @_categoryUsageCount(props, categories)

    allInInbox = @_allInInbox(usageCount, numThreads)

    displayData = {usageCount, numThreads}

    categoryData = _.chain(categories)
      .filter(_.partial(@_isUserFacing, allInInbox))
      .filter(_.partial(@_isInSearch, searchValue))
      .map(_.partial(@_itemForCategory, displayData))
      .value()

    if searchValue.length > 0
      newItemData =
        searchValue: searchValue
        newCategoryItem: true
        id: "category-create-new"
      categoryData.push(newItemData)

    return {categoryData, searchValue}

  _categoryUsageCount: (props, categories) =>
    categoryUsageCount = {}
    _.flatten(@_threads(props).map(@_threadCategories)).forEach (category) ->
      categoryUsageCount[category.id] ?= 0
      categoryUsageCount[category.id] += 1
    return categoryUsageCount

  _isInSearch: (searchValue, category) ->
    return Utils.wordSearchRegExp(searchValue).test(category.displayName)

  _isUserFacing: (allInInbox, category) =>
    hiddenCategories = []
    currentCategoryId = FocusedMailViewStore.mailView()?.categoryId()

    if @_account?.usesLabels()
      hiddenCategories = ["all", "spam", "trash", "drafts", "sent"]
      if allInInbox
        hiddenCategories.push("inbox")
      return false if category.divider
    else if @_account?.usesFolders()
      hiddenCategories = ["drafts", "sent"]

    return (category.name not in hiddenCategories) and (category.id isnt currentCategoryId)

  _allInInbox: (usageCount, numThreads) ->
    inbox = CategoryStore.getStandardCategory("inbox")
    return false unless inbox
    return usageCount[inbox.id] is numThreads

  _itemForCategory: ({usageCount, numThreads}, category) ->
    return category if category.divider

    item = category.toJSON()
    item.category = category
    item.backgroundColor = LabelColorizer.backgroundColorDark(category)
    item.usage = usageCount[category.id] ? 0
    item.numThreads = numThreads
    item

  _threadCategories: (thread) =>
    if @_account.usesLabels()
      return (thread.labels ? [])
    else if @_account.usesFolders()
      return (thread.folders ? [])
    else throw new Error("Invalid organizationUnit")

  _threads: (props = @props) =>
    if props.items then return (props.items ? [])
    else if props.thread then return [props.thread]
    else return []

module.exports = CategoryPicker

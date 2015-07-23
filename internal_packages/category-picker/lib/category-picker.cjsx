_ = require 'underscore'
React = require 'react'

{Utils,
 Thread,
 Actions,
 TaskQueue,
 CategoryStore,
 NamespaceStore,
 WorkspaceStore,
 ChangeLabelsTask,
 ChangeFolderTask,
 FocusedContentStore,
 FocusedCategoryStore} = require 'nylas-exports'

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
    @unsubscribers.push NamespaceStore.listen @_onStoreChanged
    @unsubscribers.push FocusedContentStore.listen @_onStoreChanged
    @unsubscribers.push FocusedCategoryStore.listen @_onStoreChanged

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
    return <span></span> unless @_namespace

    if @_namespace?.usesLabels()
      img = "ic-toolbar-tag.png"
      tooltip = "Apply Labels"
      placeholder = "Label as"
    else if @_namespace?.usesFolders()
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
            itemKey={ (categoryDatum) -> categoryDatum.id }
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

  _renderItemContent: (categoryDatum) =>
    if categoryDatum.divider
      return <Menu.Item divider={categoryDatum.divider} />
    if @_namespace?.usesLabels()
      icon = @_renderCheckbox(categoryDatum)
    else if @_namespace?.usesFolders()
      icon = @_renderFolderIcon(categoryDatum)
    else return <span></span>

    <div className="category-item">
      {icon}
      <div className="category-display-name">
        {@_renderBoldedSearchResults(categoryDatum)}
      </div>
    </div>

  _renderCheckbox: (categoryDatum) ->
    styles = {}
    styles.backgroundColor = categoryDatum.backgroundColor

    if categoryDatum.usage is 0
      checkStatus = <span></span>
    else if categoryDatum.usage < categoryDatum.numThreads
      checkStatus = <RetinaImg
        className="check-img dash"
        name="tagging-conflicted.png"
        mode={RetinaImg.Mode.ContentPreserve}
        onClick={=> @_onSelectCategory(categoryDatum)}/>
    else
      checkStatus = <RetinaImg
        className="check-img check"
        name="tagging-checkmark.png"
        mode={RetinaImg.Mode.ContentPreserve}
        onClick={=> @_onSelectCategory(categoryDatum)}/>

    <div className="check-wrap" style={styles}>
      <RetinaImg
        className="check-img check"
        name="tagging-checkbox.png"
        mode={RetinaImg.Mode.ContentPreserve}
        onClick={=> @_onSelectCategory(categoryDatum)}/>
      {checkStatus}
    </div>

  _renderFolderIcon: (categoryDatum) ->
    <RetinaImg name={"#{categoryDatum.name}.png"} fallback={'folder.png'} mode={RetinaImg.Mode.ContentIsMask} />

  _renderBoldedSearchResults: (categoryDatum) ->
    name = categoryDatum.display_name
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

  _onSelectCategory: (categoryDatum) =>
    return unless @_threads().length > 0
    return unless @_namespace
    @refs.menu.setSelectedItem(null)

    if @_namespace.usesLabels()
      if categoryDatum.usage > 0
        task = new ChangeLabelsTask
          labelsToRemove: [categoryDatum.id]
          threadIds: @_threadIds()
      else
        task = new ChangeLabelsTask
          labelsToAdd: [categoryDatum.id]
          threadIds: @_threadIds()
    else if @_namespace.usesFolders()
      task = new ChangeFolderTask
        folderOrId: categoryDatum.id
        threadIds: @_threadIds()
      if @props.thread
        Actions.moveThread(@props.thread, task)
      else if @props.items
        Actions.moveThreads(@_threads(), task)

    else throw new Error("Invalid organizationUnit")

    @refs.popover.close()
    TaskQueue.enqueue(task)

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
    @_namespace = NamespaceStore.current()
    return unless @_namespace

    categories = [].concat(CategoryStore.getStandardCategories())
      .concat([{divider: true}])
      .concat(CategoryStore.getUserCategories())

    usageCount = @_categoryUsageCount(props, categories)

    allInInbox = @_allInInbox(usageCount, numThreads)

    displayData = {usageCount, numThreads}

    categoryData = _.chain(categories)
      .filter(_.partial(@_isUserFacing, allInInbox))
      .filter(_.partial(@_isInSearch, searchValue))
      .map(_.partial(@_extendCategoryWithDisplayData, displayData))
      .value()

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
    currentCategoryId = FocusedCategoryStore.categoryId()
    if @_namespace?.usesLabels()
      hiddenCategories = ["all", "spam", "trash", "drafts", "sent"]
      if allInInbox
        hiddenCategories.push("inbox")
      return false if category.divider
    else if @_namespace?.usesFolders()
      hiddenCategories = ["drafts", "sent"]

    return (category.name not in hiddenCategories) and (category.id isnt currentCategoryId)

  _allInInbox: (usageCount, numThreads) ->
    inbox = CategoryStore.getStandardCategory("inbox")
    return usageCount[inbox.id] is numThreads

  _extendCategoryWithDisplayData: ({usageCount, numThreads}, category) ->
    return category if category.divider
    cat = category.toJSON()
    usage = usageCount[cat.id] ? 0
    cat.backgroundColor = LabelColorizer.backgroundColorDark(category)
    cat.usage = usage
    cat.numThreads = numThreads
    return cat

  _threadCategories: (thread) =>
    if @_namespace.usesLabels()
      return (thread.labels ? [])
    else if @_namespace.usesFolders()
      return (thread.folders ? [])
    else throw new Error("Invalid organizationUnit")

  _threads: (props=@props) =>
    if props.items then return (props.items ? [])
    else if props.thread then return [props.thread]
    else return []

  _threadIds: =>
    @_threads().map (thread) -> thread.id

module.exports = CategoryPicker

_ = require 'underscore'
React = require 'react'

{Actions,
 TaskQueue,
 CategoryStore,
 NamespaceStore,
 ChangeLabelsTask,
 ChangeFolderTask,
 FocusedContentStore} = require 'nylas-exports'

{Menu,
 Popover,
 RetinaImg} = require 'nylas-component-kit'

# This changes the category on one or more threads.
#
# See internal_packages/thread-list/lib/thread-buttons.cjsx
# See internal_packages/message-list/lib/thread-tags-button.cjsx
# See internal_packages/message-list/lib/thread-archive-button.cjsx
# See internal_packages/message-list/lib/message-toolbar-items.cjsx

class CategoryPicker extends React.Component
  @displayName: "CategoryPicker"
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = _.extend @_recalculateState(@props), searchValue: ""

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push CategoryStore.listen @_onStoreChanged
    @unsubscribers.push NamespaceStore.listen @_onStoreChanged
    @unsubscribers.push FocusedContentStore.listen @_onStoreChanged

    @_commandUnsubscriber = atom.commands.add 'body',
      "application:change-category": @_onChangeCategory

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
    button = <button className="btn btn-toolbar" data-tooltip={@_tooltipLabel()}>
      <RetinaImg name="toolbar-tags.png" mode={RetinaImg.Mode.ContentIsMask}/>
      <RetinaImg name="toolbar-chevron.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

    headerComponents = [
      <input type="text"
             tabIndex="1"
             key="textfield"
             className="search"
             value={@state.searchValue}
             onChange={@_onSearchValueChange}/>
    ]

    <Popover className="tag-picker"
             ref="popover"
             onOpened={@_onPopoverOpened}
             direction="down"
             buttonComponent={button}>
      <Menu ref="menu"
            headerComponents={headerComponents}
            footerComponents={[]}
            items={@state.categoryData}
            itemKey={ (categoryDatum) -> categoryDatum.id }
            itemContent={@_itemContent}
            itemChecked={ (categoryDatum) -> categoryDatum.usage > 0 }
            onSelect={@_onSelectCategory}
            />
    </Popover>

  _tooltipLabel: ->
    return "" unless @_namespace
    if @_namespace.usesLabels()
      return "Apply Labels"
    else if @_namespace.usesFolders()
      return "Move to Folder"

  _onChangeCategory: =>
    return unless @_threads().length > 0
    @refs.popover.open()

  _itemContent: (categoryDatum) =>
    <span className="category-item">{categoryDatum.display_name}</span>

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
      else if @props.selection
        Actions.moveThreads(@_threads(), task)

    else throw new Error("Invalid organizationUnit")

    TaskQueue.enqueue(task)

  _onStoreChanged: =>
    @setState @_recalculateState(@props)

  _onSearchValueChange: (event) =>
    @setState @_recalculateState(@props, searchValue: event.target.value)

  _onPopoverOpened: =>
    @setState @_recalculateState(@props, searchValue: "")

  _recalculateState: (props=@props, {searchValue}={}) =>
    searchValue = searchValue ? @state?.searchValue ? ""
    if @_threads(props).length is 0
      return {categoryData: [], searchValue}
    @_namespace = NamespaceStore.current()
    return unless @_namespace

    categories = CategoryStore.getCategories()
    usageCount = @_categoryUsageCount(props, categories)
    categoryData = _.chain(categories)
      .filter(@_isUserFacing)
      .filter(_.partial(@_isInSearch, searchValue))
      .map(_.partial(@_extendCategoryWithUsage, usageCount))
      .value()

    return {categoryData, searchValue}

  _categoryUsageCount: (props, categories) =>
    categoryUsageCount = {}
    _.flatten(@_threads(props).map(@_threadCategories)).forEach (category) ->
      categoryUsageCount[category.id] ?= 0
      categoryUsageCount[category.id] += 1
    return categoryUsageCount

  _isInSearch: (searchValue, category) ->
    searchTerm = searchValue.trim().toLowerCase()
    return true if searchTerm.length is 0

    catName = category.displayName.trim().toLowerCase()

    wordIndices = []
    # Where a non-word character is followed by a word character
    # We don't use \b (word boundary) because we want to split on slashes
    # and dashes and other non word things
    re = /\W[\w\d]/g
    while match = re.exec(catName) then wordIndices.push(match.index)
    # To shift to the start of each word.
    wordIndices = wordIndices.map (i) -> i += 1

    # Always include the start
    wordIndices.push(0)

    return catName.indexOf(searchTerm) in wordIndices

  _isUserFacing: (category) =>
    hiddenCategories = ["inbox", "all", "archive", "drafts", "sent"]
    return category.name not in hiddenCategories

  _extendCategoryWithUsage: (usageCount, category, i, categories) ->
    cat = category.toJSON()
    usage = usageCount[cat.id] ? 0
    cat.usage = usage
    cat.totalUsage = categories.length
    return cat

  _threadCategories: (thread) =>
    if @_namespace.usesLabels()
      return (thread.labels ? [])
    else if @_namespace.usesFolders()
      return (thread.folders ? [])
    else throw new Error("Invalid organizationUnit")

  _threads: (props=@props) =>
    if props.selection then return (props.selection.items() ? [])
    else if props.thread then return [props.thread]
    else return []

  _threadIds: =>
    @_threads().map (thread) -> thread.id

module.exports = CategoryPicker

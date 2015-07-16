_ = require 'underscore'
React = require 'react'
Reflux = require 'reflux'
classNames = require 'classnames'
{Actions,
 Utils,
 FocusedContentStore,
 FocusedContentStore,
 DatabaseStore,
 Tag,
 Thread,
 TaskQueue} = require 'nylas-exports'
{RetinaImg,
 Popover,
 Menu} = require 'nylas-component-kit'

TagsStore = Reflux.createStore
  init: ->
    @_setStoreDefaults()
    @_registerListeners()
    @_fetch()

  items: ->
    @_items

  _setStoreDefaults: ->
    @_items = []

  _registerListeners: ->
    @listenTo DatabaseStore, @_onDataChanged

  _onDataChanged: (change) ->
    if change and change.objectClass is Tag.name
      @_fetch()

  _fetch: ->
    DatabaseStore.findAll(Tag).then (tags) =>
      @_items = tags
      @trigger()


# Note
class ThreadTagsButton extends React.Component
  @displayName: 'ThreadTagsButton'

  constructor: (@props) ->
    @state = @_getStateForSearch('')
    @

  componentDidMount: ->
    @unsubscribers = []
    @unsubscribers.push TagsStore.listen @_onStoreChange
    @unsubscribers.push FocusedContentStore.listen @_onFocusChange

  componentWillUnmount: =>
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    button = <button className="btn btn-toolbar">
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
             direction="down"
             onOpened={@_onShowTags}
             buttonComponent={button}>
      <Menu ref="menu"
            headerComponents={headerComponents}
            footerComponents={[]}
            items={@state.tags}
            itemKey={ (item) -> item.id }
            itemContent={@_itemContent}
            itemChecked={@_itemChecked}
            onSelect={@_onToggleTag}
            />
    </Popover>

  _itemContent: (tag) =>
    if tag.id is 'divider'
      <Menu.Item divider={tag.name} />
    else
      tag.name.charAt(0).toUpperCase() + tag.name.slice(1)

  _itemChecked: (tag) =>
    return false unless @state.thread
    @state.thread.hasCategoryId(tag.id)

  _onShowTags: =>
    # Always reset search state when the popover is shown
    if @state.searchValue.length > 0
      @setState @_getStateForSearch('')

  _onToggleTag: (tag) =>
    return unless @state.thread

    if @state.thread.hasCategoryId(tag.id)
      task = new AddRemoveTagsTask(@state.thread, [], [tag.id])
    else
      task = new AddRemoveTagsTask(@state.thread, [tag.id], [])

    @refs.menu.setSelectedItem(null)

    TaskQueue.enqueue(task)

  _onFocusChange: (change) =>
    if change.impactsCollection('thread')
      @_onStoreChange()

  _onStoreChange: =>
    @setState @_getStateForSearch(@state.searchValue)

  _onSearchValueChange: (event) =>
    @setState @_getStateForSearch(event.target.value)

  _getStateForSearch: (searchValue = '') =>
    searchTerm = searchValue.toLowerCase()
    thread = FocusedContentStore.focused('thread')
    return [] unless thread

    tags = _.filter TagsStore.items(), (tag) -> tag.name.toLowerCase().indexOf(searchTerm) is 0

    # Some tags are "magic" state and can't be added/removed
    tags = _.filter tags, (tag) -> not (tag.id in ['unseen', 'attachment', 'sending', 'drafts', 'sent'])

    # Some tags are readonly
    tags = _.filter tags, (tag) -> not tag.readonly

    # Organize tags into currently applied / not applied
    active = []
    inactive = []
    for tag in tags
      if thread.hasCategoryId(tag.id)
        active.push(tag)
      else
        inactive.push(tag)

    {searchValue, thread, tags: [].concat(active, inactive)}

module.exports = ThreadTagsButton

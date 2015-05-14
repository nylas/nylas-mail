_ = require 'underscore-plus'
React = require 'react'
classNames = require 'classnames'
ListTabular = require './list-tabular'
EmptyState = require './empty-state'
Spinner = require './spinner'
{Actions,
 Utils,
 WorkspaceStore,
 FocusedContentStore,
 NamespaceStore} = require 'inbox-exports'
EventEmitter = require('events').EventEmitter

###
Public: MultiselectList wraps {ListTabular} and makes it easy to present a
{ModelView} with selection support. It adds a checkbox column to the columns
you provide, and also handles:

- Command-clicking individual items
- Shift-clicking to select a range
- Using the keyboard to select a range

Section: Component Kit
###
class MultiselectList extends React.Component
  @displayName = 'MultiselectList'

  @propTypes =
    className: React.PropTypes.string.isRequired
    collection: React.PropTypes.string.isRequired
    commands: React.PropTypes.object.isRequired
    columns: React.PropTypes.array.isRequired
    dataStore: React.PropTypes.object.isRequired
    itemPropsProvider: React.PropTypes.func.isRequired

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @setupForProps(@props)

  componentWillReceiveProps: (newProps) =>
    return if _.isEqual(@props, newProps)
    @teardownForProps()
    @setupForProps(newProps)
    @setState(@_getStateFromStores(newProps))

  componentDidUpdate: (prevProps, prevState) =>
    if prevState.focusedId isnt @state.focusedId or
       prevState.keyboardCursorId isnt @state.keyboardCursorId

      item = React.findDOMNode(@).querySelector(".focused")
      item ?= React.findDOMNode(@).querySelector(".keyboard-cursor")
      list = React.findDOMNode(@refs.list)
      Utils.scrollNodeToVisibleInContainer(item, list)

  componentWillUnmount: =>
    @teardownForProps()

  teardownForProps: =>
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers
    @command_unsubscriber.dispose()

  setupForProps: (props) =>
    commands = _.extend {},
      'core:focus-item': => @_onEnter()
      'core:select-item': => @_onSelect()
      'core:next-item': => @_onShift(1)
      'core:previous-item': => @_onShift(-1)
      'core:select-down': => @_onShift(1, {select: true})
      'core:select-up': => @_onShift(-1, {select: true})
      'application:pop-sheet': => @_onDeselect()

    Object.keys(props.commands).forEach (key) =>
      commands[key] = =>
        context = {focusedId: @state.focusedId}
        props.commands[key](context)

    unless props.columns[0].name is 'Check'
      checkmarkColumn = new ListTabular.Column
        name: "Check"
        resolver: (thread) =>
          toggle = (event) =>
            if event.shiftKey
              props.dataStore.view().selection.expandTo(thread)
            else
              props.dataStore.view().selection.toggle(thread)
            event.stopPropagation()
          <div className="checkmark" onClick={toggle}><div className="inner"></div></div>
      props.columns.splice(0, 0, checkmarkColumn)

    @unsubscribers = []
    @unsubscribers.push props.dataStore.listen @_onChange
    @unsubscribers.push FocusedContentStore.listen @_onChange
    @command_unsubscriber = atom.commands.add('body', commands)

  render: =>
    # IMPORTANT: DO NOT pass inline functions as props. _.isEqual thinks these
    # are "different", and will re-render everything. Instead, declare them with ?=,
    # pass a reference. (Alternatively, ignore these in children's shouldComponentUpdate.)
    #
    # BAD:   onSelect={ (item) -> Actions.focusThread(item) }
    # GOOD:  onSelect={@_onSelectItem}
    #
    className = @props.className
    className += " ready" if @state.ready

    @itemPropsProvider ?= (item) =>
      props = @props.itemPropsProvider(item)
      props.className ?= ''
      props.className += " " + classNames
        'selected': item.id in @state.selectedIds
        'focused': @state.showFocus and item.id is @state.focusedId
        'keyboard-cursor': @state.showKeyboardCursor and item.id is @state.keyboardCursorId
      props

    if @state.dataView
      <div className={className}>
        <ListTabular
          ref="list"
          columns={@props.columns}
          dataView={@state.dataView}
          itemPropsProvider={@itemPropsProvider}
          onSelect={@_onClickItem}
          onDoubleClick={@props.onDoubleClick} />
        <Spinner visible={!@state.ready} />
        <EmptyState visible={@state.ready && @state.dataView.count() is 0} />
      </div>
    else
      <div className={className}>
        <Spinner visible={@state.ready is false} />
      </div>

  _onClickItem: (item, event) =>
    if event.metaKey
      @state.dataView.selection.toggle(item)
      if @state.showKeyboardCursor
        Actions.focusKeyboardInCollection({collection: @props.collection, item: item})
    else if event.shiftKey
      @state.dataView.selection.expandTo(item)
      if @state.showKeyboardCursor
        Actions.focusKeyboardInCollection({collection: @props.collection, item: item})
    else
      Actions.focusInCollection({collection: @props.collection, item: item})

  _onEnter: =>
    return unless @state.showKeyboardCursor
    item = @state.dataView.getById(@state.keyboardCursorId)
    if item
      Actions.focusInCollection({collection: @props.collection, item: item})

  _onSelect: =>
    if @state.showKeyboardCursor and @_visible()
      id = @state.keyboardCursorId
    else
      id = @state.focusedId

    return unless id
    @state.dataView.selection.toggle(@state.dataView.getById(id))

  _onDeselect: =>
    return unless @_visible()
    @state.dataView.selection.clear()

  _onShift: (delta, options = {}) =>
    if @state.showKeyboardCursor and @_visible()
      id = @state.keyboardCursorId
      action = Actions.focusKeyboardInCollection
    else
      id = @state.focusedId
      action = Actions.focusInCollection

    current = @state.dataView.getById(id)
    index = @state.dataView.indexOfId(id)
    index = Math.max(0, Math.min(index + delta, @state.dataView.count() - 1))
    next = @state.dataView.get(index)

    action({collection: @props.collection, item: next})

    if options.select
      @state.dataView.selection.walk({current, next})

  _visible: =>
    if WorkspaceStore.layoutMode() is "list"
      WorkspaceStore.topSheet().root
    else
      true

  # This onChange handler can be called many times back to back and setState
  # sometimes triggers an immediate render. Ensure that we never render back-to-back,
  # because rendering this view (even just to determine that there are no changes)
  # is expensive.
  _onChange: =>
    @_onChangeDebounced ?= _.debounce =>
      @setState(@_getStateFromStores())
    , 1
    @_onChangeDebounced()

  _getStateFromStores: (props) =>
    props ?= @props

    view = props.dataStore?.view()
    return {} unless view

    dataView: view
    ready: view.loaded()
    selectedIds: view.selection.ids()
    focusedId: FocusedContentStore.focusedId(props.collection)
    keyboardCursorId: FocusedContentStore.keyboardCursorId(props.collection)
    showFocus: !FocusedContentStore.keyboardCursorEnabled()
    showKeyboardCursor: FocusedContentStore.keyboardCursorEnabled()


module.exports = MultiselectList

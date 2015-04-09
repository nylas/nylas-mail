_ = require 'underscore-plus'
React = require 'react'
ListTabular = require './list-tabular'
Spinner = require './spinner'
{Actions,
 Utils,
 WorkspaceStore,
 FocusedContentStore,
 NamespaceStore} = require 'inbox-exports'
EventEmitter = require('events').EventEmitter

module.exports =
ModelList = React.createClass
  displayName: 'ModelList'

  propTypes:
    className: React.PropTypes.string.isRequired
    collection: React.PropTypes.string.isRequired
    commands: React.PropTypes.object.isRequired
    columns: React.PropTypes.array.isRequired
    dataStore: React.PropTypes.object.isRequired
    itemClassProvider: React.PropTypes.func.isRequired

  getInitialState: ->
    @_getStateFromStores()
 
  componentDidMount: ->
    @setupForProps(@props)

  componentWillReceiveProps: (newProps) ->
    return if _.isEqual(@props, newProps)
    @teardownForProps()
    @setupForProps(newProps)
    @setState(@_getStateFromStores(newProps))

  componentWillUnmount: ->
    @teardownForProps()

  teardownForProps: ->
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers
    @command_unsubscriber.dispose()

  setupForProps: (props) ->
    commands = _.extend {},
      'core:focus-item': => @_onEnter()
      'core:select-item': => @_onSelect()
      'core:next-item': => @_onShift(1)
      'core:previous-item': => @_onShift(-1)
      'core:select-down': => @_onShift(1, {select: true})
      'core:select-up': => @_onShift(-1, {select: true})

    Object.keys(props.commands).forEach (key) =>
      commands[key] = =>
        context = {focusedId: @state.focusedId}
        props.commands[key](context)

    @unsubscribers = []
    @unsubscribers.push props.dataStore.listen @_onChange
    @unsubscribers.push FocusedContentStore.listen @_onChange
    @command_unsubscriber = atom.commands.add('body', commands)

  render: ->
    # IMPORTANT: DO NOT pass inline functions as props. _.isEqual thinks these
    # are "different", and will re-render everything. Instead, declare them with ?=,
    # pass a reference. (Alternatively, ignore these in children's shouldComponentUpdate.)
    #
    # BAD:   onSelect={ (item) -> Actions.focusThread(item) }
    # GOOD:  onSelect={@_onSelectItem}
    #
    className = @props.className
    className += " ready" if @state.ready

    @itemClassProvider ?= (item) =>
      @props.itemClassProvider(item) + " " + React.addons.classSet
        'selected': item.id in @state.selectedIds
        'focused': @state.showFocus and item.id is @state.focusedId
        'keyboard-cursor': @state.showKeyboardCursor and item.id is @state.keyboardCursorId

    if @state.dataView
      <div className={className}>
        <ListTabular
          columns={@props.columns}
          dataView={@state.dataView}
          itemClassProvider={@itemClassProvider}
          onSelect={@_onClickItem}
          onDoubleClick={@props.onDoubleClick} />
        <Spinner visible={!@state.ready} />
      </div>
    else
      <div className={className}>
        <Spinner visible={!@state.ready} />
      </div>

  _onClickItem: (item, event) ->
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

  _onEnter: ->
    return unless @state.showKeyboardCursor
    item = @state.dataView.getById(@state.keyboardCursorId)
    if item
      Actions.focusInCollection({collection: @props.collection, item: item})

  _onSelect: ->
    if @state.showKeyboardCursor and @_visible()
      id = @state.keyboardCursorId
    else
      id = @state.focusedId

    return unless id
    @state.dataView.selection.toggle(@state.dataView.getById(id))

  _onShift: (delta, options = {}) ->
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

  _visible: ->
    if WorkspaceStore.selectedLayoutMode() is "list"
      WorkspaceStore.sheet().type is "Root"
    else
      true

  # Message list rendering is more important than thread list rendering.
  # Since they're on the same event listner, and the event listeners are
  # unordered, we need a way to push thread list updates later back in the
  # queue.
  _onChange: -> _.delay =>
    return unless @isMounted()
    @setState(@_getStateFromStores())
  , 1

  _getStateFromStores: (props) ->
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

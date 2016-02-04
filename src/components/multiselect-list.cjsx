_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
ListTabular = require './list-tabular'
Spinner = require './spinner'
{Actions,
 Utils,
 WorkspaceStore,
 AccountStore} = require 'nylas-exports'
{KeyCommandsRegion} = require 'nylas-component-kit'
EventEmitter = require('events').EventEmitter

MultiselectListInteractionHandler = require './multiselect-list-interaction-handler'
MultiselectSplitInteractionHandler = require './multiselect-split-interaction-handler'

###
Public: MultiselectList wraps {ListTabular} and makes it easy to present a
{ListDataSource} with selection support. It adds a checkbox column to the columns
you provide, and also handles:

- Command-clicking individual items
- Shift-clicking to select a range
- Using the keyboard to select a range

Section: Component Kit
###
class MultiselectList extends React.Component
  @displayName = 'MultiselectList'

  @propTypes =
    dataSource: React.PropTypes.object
    className: React.PropTypes.string.isRequired
    columns: React.PropTypes.array.isRequired
    itemPropsProvider: React.PropTypes.func.isRequired
    keymapHandlers: React.PropTypes.object

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
    if prevProps.focusedId isnt @props.focusedId or
       prevProps.keyboardCursorId isnt @props.keyboardCursorId

      item = React.findDOMNode(@).querySelector(".focused")
      item ?= React.findDOMNode(@).querySelector(".keyboard-cursor")
      return unless item instanceof Node
      @refs.list.scrollTo(item)

  componentWillUnmount: =>
    @teardownForProps()

  teardownForProps: =>
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers

  setupForProps: (props) =>
    @unsubscribers = []
    @unsubscribers.push WorkspaceStore.listen @_onChange

  _globalKeymapHandlers: ->
    _.extend({}, @props.keymapHandlers, {
      'core:focus-item': => @_onEnter()
      'core:select-item': => @_onSelect()
      'core:next-item': => @_onShift(1)
      'core:previous-item': => @_onShift(-1)
      'core:select-down': => @_onShift(1, {select: true})
      'core:select-up': => @_onShift(-1, {select: true})
      'core:list-page-up': => @_onScrollByPage(-1)
      'core:list-page-down': => @_onScrollByPage(1)
      'application:pop-sheet': => @_onDeselect()
      'multiselect-list:select-all': => @_onSelectAll()
      'multiselect-list:deselect-all': => @_onDeselect()
    })

  render: =>
    # IMPORTANT: DO NOT pass inline functions as props. _.isEqual thinks these
    # are "different", and will re-render everything. Instead, declare them with ?=,
    # pass a reference. (Alternatively, ignore these in children's shouldComponentUpdate.)
    #
    # BAD:   onSelect={ (item) -> Actions.focusThread(item) }
    # GOOD:  onSelect={@_onSelectItem}
    #
    otherProps = _.omit(@props, _.keys(@constructor.propTypes))

    className = @props.className
    if @props.dataSource and @state.handler
      className += " " + @state.handler.cssClass()

      @itemPropsProvider ?= (item, idx) =>
        selectedIds = @props.dataSource.selection.ids()
        selected = item.id in selectedIds
        if not selected
          nextId = @props.dataSource.get(idx + 1)?.id
          nextSelected = nextId in selectedIds

        props = @props.itemPropsProvider(item, idx)
        props.className ?= ''
        props.className += " " + classNames
          'selected': selected
          'next-is-selected': not selected and nextSelected
          'focused': @state.handler.shouldShowFocus() and item.id is @props.focusedId
          'keyboard-cursor': @state.handler.shouldShowKeyboardCursor() and item.id is @props.keyboardCursorId
        props['data-item-id'] = item.id
        props

      <KeyCommandsRegion globalHandlers={@_globalKeymapHandlers()} className={className}>
        <ListTabular
          ref="list"
          columns={@state.computedColumns}
          dataSource={@props.dataSource}
          itemPropsProvider={@itemPropsProvider}
          onSelect={@_onClickItem}
          {...otherProps} />
      </KeyCommandsRegion>
    else
      <div className={className} {...otherProps}>
        <Spinner visible={true} />
      </div>

  _onClickItem: (item, event) =>
    return unless @state.handler
    if event.metaKey || event.ctrlKey
      @state.handler.onMetaClick(item)
    else if event.shiftKey
      @state.handler.onShiftClick(item)
    else
      @state.handler.onClick(item)

  _onEnter: =>
    return unless @state.handler
    @state.handler.onEnter()

  _onSelect: =>
    return unless @state.handler
    @state.handler.onSelect()

  _onSelectAll: =>
    return unless @state.handler
    items = @props.dataSource.itemsCurrentlyInViewMatching -> true
    @props.dataSource.selection.set(items)

  _onDeselect: =>
    return unless @_visible() and @props.dataSource
    @props.dataSource.selection.clear()

  _onShift: (delta, options = {}) =>
    return unless @state.handler
    @state.handler.onShift(delta, options)

  _onScrollByPage: (delta) =>
    @refs.list.scrollByPage(delta)

  _onChange: =>
    @setState(@_getStateFromStores())

  _visible: =>
    if @state.layoutMode
      WorkspaceStore.topSheet().root
    else
      true

  _getCheckmarkColumn: =>
    new ListTabular.Column
      name: 'Check'
      resolver: (item) =>
        toggle = (event) =>
          if event.shiftKey
            @state.handler.onShiftClick(item)
          else
            @state.handler.onMetaClick(item)
          event.stopPropagation()
        <div className="checkmark" onClick={toggle}><div className="inner"></div></div>

  _getStateFromStores: (props = @props) =>
    state = @state ? {}

    layoutMode = WorkspaceStore.layoutMode()

    # Do we need to re-compute columns? Don't do this unless we really have to,
    # it will cause a re-render of the entire ListTabular. To know whether our
    # computed columns are still valid, we store the original columns in our state
    # along with the computed ones.
    if props.columns isnt state.columns or layoutMode isnt state.layoutMode
      computedColumns = [].concat(props.columns)
      if layoutMode is 'list'
        computedColumns.splice(0, 0, @_getCheckmarkColumn())
    else
      computedColumns = state.computedColumns

    if layoutMode is 'list'
      handler = new MultiselectListInteractionHandler(props)
    else
      handler = new MultiselectSplitInteractionHandler(props)

    handler: handler
    columns: props.columns
    computedColumns: computedColumns
    layoutMode: layoutMode

  # Public Methods

  itemIdAtPoint: (x, y) ->
    item = document.elementFromPoint(event.clientX, event.clientY).closest('.list-item')
    return null unless item
    return item.dataset.itemId

module.exports = MultiselectList

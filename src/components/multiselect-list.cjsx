_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
ListTabular = require './list-tabular'
Spinner = require './spinner'
{Actions,
 Utils,
 WorkspaceStore,
 FocusedContentStore,
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
    className: React.PropTypes.string.isRequired
    collection: React.PropTypes.string.isRequired
    columns: React.PropTypes.array.isRequired
    dataStore: React.PropTypes.object.isRequired
    itemPropsProvider: React.PropTypes.func.isRequired
    itemHeight: React.PropTypes.number.isRequired
    scrollTooltipComponent: React.PropTypes.func
    emptyComponent: React.PropTypes.func
    keymapHandlers: React.PropTypes.object
    onDoubleClick: React.PropTypes.func

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
      return unless item instanceof Node
      @refs.list.scrollTo(item)

  componentWillUnmount: =>
    @teardownForProps()

  teardownForProps: =>
    return unless @unsubscribers
    unsubscribe() for unsubscribe in @unsubscribers

  setupForProps: (props) =>
    @unsubscribers = []
    @unsubscribers.push props.dataStore.listen @_onChange
    @unsubscribers.push WorkspaceStore.listen @_onChange
    @unsubscribers.push FocusedContentStore.listen @_onChange

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
      'multiselect-list:select-all': @_onSelectAll
      'multiselect-list:select-all': @_onSelectAll
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
    if @state.dataSource and @state.handler
      className += " " + @state.handler.cssClass()

      @itemPropsProvider ?= (item) =>
        props = @props.itemPropsProvider(item)
        props.className ?= ''
        props.className += " " + classNames
          'selected': item.id in @state.selectedIds
          'focused': @state.handler.shouldShowFocus() and item.id is @state.focusedId
          'keyboard-cursor': @state.handler.shouldShowKeyboardCursor() and item.id is @state.keyboardCursorId
        props

      emptyElement = []
      if @props.emptyComponent
        emptyElement = <@props.emptyComponent
          visible={@state.loaded and @state.empty}
          dataSource={@state.dataSource} />

      <KeyCommandsRegion globalHandlers={@_globalKeymapHandlers()} className="multiselect-list">
        <div className={className} {...otherProps}>
          <ListTabular
            ref="list"
            columns={@state.computedColumns}
            scrollTooltipComponent={@props.scrollTooltipComponent}
            dataSource={@state.dataSource}
            itemPropsProvider={@itemPropsProvider}
            itemHeight={@props.itemHeight}
            onSelect={@_onClickItem}
            onDoubleClick={@props.onDoubleClick} />
          <Spinner visible={!@state.loaded and @state.empty} />
          {emptyElement}
        </div>
      </KeyCommandsRegion>
    else
      <div className={className} {...otherProps}>
        <Spinner visible={true} />
      </div>

  _onClickItem: (item, event) =>
    return unless @state.handler
    if event.metaKey
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
    items = @state.dataSource.itemsCurrentlyInViewMatching -> true
    @state.dataSource.selection.set(items)

  _onDeselect: =>
    return unless @_visible() and @state.dataSource
    @state.dataSource.selection.clear()

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

  _getStateFromStores: (props) =>
    props ?= @props
    state = @state ? {}

    layoutMode = WorkspaceStore.layoutMode()
    dataSource = props.dataStore?.dataSource()
    return {} unless dataSource

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
      handler = new MultiselectListInteractionHandler(dataSource, props.collection)
    else
      handler = new MultiselectSplitInteractionHandler(dataSource, props.collection)

    dataSource: dataSource
    handler: handler
    columns: props.columns
    computedColumns: computedColumns
    layoutMode: layoutMode
    selectedIds: dataSource.selection.ids()
    focusedId: FocusedContentStore.focusedId(props.collection)
    keyboardCursorId: FocusedContentStore.keyboardCursorId(props.collection)
    loaded: dataSource.loaded()
    empty: dataSource.empty()

module.exports = MultiselectList

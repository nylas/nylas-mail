_ = require 'underscore'
React = require 'react/addons'
ScrollRegion = require './scroll-region'
Spinner = require './spinner'
{Utils} = require 'nylas-exports'

ListDataSource = require './list-data-source'
ListSelection = require './list-selection'
ListTabularItem = require './list-tabular-item'

class ListColumn
  constructor: ({@name, @resolver, @flex, @width}) ->

class ListTabular extends React.Component
  @displayName = 'ListTabular'
  @propTypes =
    columns: React.PropTypes.arrayOf(React.PropTypes.object).isRequired
    dataSource: React.PropTypes.object
    itemPropsProvider: React.PropTypes.func
    itemHeight: React.PropTypes.number
    onSelect: React.PropTypes.func
    onClick: React.PropTypes.func
    onDoubleClick: React.PropTypes.func

  constructor: (@props) ->
    if not @props.itemHeight
      throw new Error("ListTabular: You must provide an itemHeight - raising to avoid divide by zero errors.")

    @state = @buildStateForRange(start: -1, end: -1)

  componentDidMount: =>
    window.addEventListener('resize', @onWindowResize, true)
    @setupDataSource(@props.dataSource)
    @updateRangeState()

  componentWillUnmount: =>
    window.removeEventListener('resize', @onWindowResize, true)
    window.clearTimeout(@_cleanupAnimationTimeout) if @_cleanupAnimationTimeout
    @_unlisten?()

  componentWillReceiveProps: (nextProps) =>
    if nextProps.dataSource isnt @props.dataSource
      @setupDataSource(nextProps.dataSource)

  setupDataSource: (dataSource) =>
    @_unlisten?()
    @_unlisten = dataSource.listen =>
      @setState(@buildStateForRange())
    @setState(@buildStateForRange(dataSource: dataSource))

  buildStateForRange: ({dataSource, start, end} = {}) =>
    start ?= @state.renderedRangeStart
    end ?= @state.renderedRangeEnd
    dataSource ?= @props.dataSource

    items = {}
    animatingOut = {}

    [start..end].forEach (idx) =>
      items[idx] = dataSource.get(idx)

    # If we have a previous state, and the previous range matches the new range,
    # (eg: we're not scrolling), identify removed items. We'll render them in one
    # last time but not allocate height to them. This allows us to animate them
    # being covered by other items, not just disappearing when others start to slide up.
    if @state and start is @state.renderedRangeStart
      nextIds = _.pluck(_.values(items), 'id')
      animatingOut = {}

      # Keep items which are still animating out and are still not in the set
      for recordIdx, record of @state.animatingOut
        if Date.now() < record.end and not (record.item.id in nextIds)
          animatingOut[recordIdx] = record

      # Add items which are no longer found in the set
      for previousIdx, previousItem of @state.items
        continue if !previousItem or previousItem.id in nextIds
        animatingOut[previousIdx] =
          item: previousItem
          idx: previousIdx
          end: Date.now() + 125

      # If we think /all/ the items are animating out, or a lot of them,
      # the user probably switched to an entirely different perspective.
      # Don't bother trying to animate.
      animatingCount = Object.keys(animatingOut).length
      if animatingCount > 8 or animatingCount is Object.keys(@state.items).length
        animatingOut = {}

    renderedRangeStart: start
    renderedRangeEnd: end
    count: dataSource.count()
    loaded: dataSource.loaded()
    empty: dataSource.empty()
    items: items
    animatingOut: animatingOut

  componentDidUpdate: (prevProps, prevState) =>
    # If our view has been swapped out for an entirely different one,
    # reset our scroll position to the top.
    if prevProps.dataSource isnt @props.dataSource
      @refs.container.scrollTop = 0

    unless @updateRangeStateFiring
      @updateRangeState()
    @updateRangeStateFiring = false

    unless @_cleanupAnimationTimeout
      @_cleanupAnimationTimeout = window.setTimeout(@onCleanupAnimatingItems, 50)

  onCleanupAnimatingItems: =>
    @_cleanupAnimationTimeout = null

    nextAnimatingOut = {}
    for idx, record of @state.animatingOut
      if Date.now() < record.end
        nextAnimatingOut[idx] = record

    if Object.keys(nextAnimatingOut).length < Object.keys(@state.animatingOut).length
      @setState(animatingOut: nextAnimatingOut)

    if Object.keys(nextAnimatingOut).length > 0
      @_cleanupAnimationTimeout = window.setTimeout(@onCleanupAnimatingItems, 50)

  onWindowResize: =>
    @_onWindowResize ?= _.debounce(@updateRangeState, 50)
    @_onWindowResize()

  onScroll: =>
    # If we've shifted enough pixels from our previous scrollTop to require
    # new rows to be rendered, update our state!
    @updateRangeState()

  updateRangeState: =>
    scrollTop = @refs.container.scrollTop

    # Determine the exact range of rows we want onscreen
    rangeStart = Math.floor(scrollTop / @props.itemHeight)
    rangeSize = Math.ceil(window.innerHeight / @props.itemHeight)
    rangeEnd = rangeStart + rangeSize

    # Expand the start/end so that you can advance the keyboard cursor fast and
    # we have items to move to and then scroll to.
    rangeStart = Math.max(0, rangeStart - 2)
    rangeEnd = Math.min(rangeEnd + 2, @state.count + 1)

    # Final sanity check to prevent needless work
    return if rangeStart is @state.renderedRangeStart and
              rangeEnd is @state.renderedRangeEnd

    @updateRangeStateFiring = true

    @props.dataSource.setRetainedRange
      start: rangeStart
      end: rangeEnd

    @setState(@buildStateForRange(start: rangeStart, end: rangeEnd))

  render: =>
    otherProps = _.omit(@props, _.keys(@constructor.propTypes))

    innerStyles =
      height: @state.count * @props.itemHeight

    emptyElement = false
    if @props.emptyComponent
      emptyElement = <@props.emptyComponent visible={@state.loaded and @state.empty} />

    <div className="list-container list-tabular #{@props.className}">
      <ScrollRegion
        ref="container"
        onScroll={@onScroll}
        tabIndex="-1"
        scrollTooltipComponent={@props.scrollTooltipComponent}>
        <div className="list-rows" style={innerStyles} {...otherProps}>
          {@_rows()}
        </div>
      </ScrollRegion>
      <Spinner visible={!@state.loaded and @state.empty} />
      {emptyElement}
    </div>

  _rows: =>
    # The ordering of the results array is important. We want current rows to
    # slide over rows which are animating out, so we need to render them last.
    results = []
    for idx, record of @state.animatingOut
      results.push @_rowForItem(record.item, idx / 1)

    [@state.renderedRangeStart..@state.renderedRangeEnd].forEach (idx) =>
      if @state.items[idx]
        results.push @_rowForItem(@state.items[idx], idx)

    results

  _rowForItem: (item, idx) =>
    return false unless item
    <ListTabularItem key={item.id ? idx}
                     item={item}
                     itemProps={@props.itemPropsProvider?(item, idx) ? {}}
                     metrics={top: idx * @props.itemHeight, height: @props.itemHeight}
                     columns={@props.columns}
                     onSelect={@props.onSelect}
                     onClick={@props.onClick}
                     onReorder={@props.onReorder}
                     onDoubleClick={@props.onDoubleClick} />

  # Public: Scroll to the DOM node provided.
  #
  scrollTo: (node) =>
    @refs.container.scrollTo(node)

  scrollByPage: (direction) =>
    height = React.findDOMNode(@refs.container).clientHeight
    @refs.container.scrollTop += height * direction


ListTabular.Item = ListTabularItem
ListTabular.Column = ListColumn
ListTabular.Selection = ListSelection
ListTabular.DataSource = ListDataSource

module.exports = ListTabular

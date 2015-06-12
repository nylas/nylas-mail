_ = require 'underscore'
React = require 'react/addons'
ScrollRegion = require './scroll-region'
{Utils} = require 'nylas-exports'

RangeChunkSize = 10

class ListColumn
  constructor: ({@name, @resolver, @flex, @width}) ->

class ListTabularItem extends React.Component
  @displayName = 'ListTabularItem'
  @propTypes =
    metrics: React.PropTypes.object
    columns: React.PropTypes.arrayOf(React.PropTypes.object).isRequired
    item: React.PropTypes.object.isRequired
    itemProps: React.PropTypes.object
    displayHeaders: React.PropTypes.bool
    onSelect: React.PropTypes.func
    onClick: React.PropTypes.func
    onDoubleClick: React.PropTypes.func

  # DO NOT DELETE unless you know what you're doing! This method cuts
  # React.Perf.wasted-time from ~300msec to 20msec by doing a deep
  # comparison of props before triggering a re-render.
  shouldComponentUpdate: (nextProps, nextState) =>
    # Quick check to avoid running isEqual if our item === existing item
    return false if _.isEqual(@props, nextProps)
    true

  render: =>
    className = "list-item list-tabular-item #{@props.itemProps?.className}"
    props = _.omit(@props.itemProps ? {}, 'className')

    <div {...props} className={className} onClick={@_onClick} style={position:'absolute', top: @props.metrics.top, width:'100%', height:@props.metrics.height, overflow: 'hidden'}>
      {@_columns()}
    </div>

  _columns: =>
    names = {}
    for column in (@props.columns ? [])
      if names[column.name]
        console.warn("ListTabular: Columns do not have distinct names, will cause React error! `#{column.name}` twice.")
      names[column.name] = true

      <div key={column.name}
           displayName={column.name}
           style={_.pick(column, ['flex', 'width'])}
           className="list-column list-column-#{column.name}">
        {column.resolver(@props.item, @)}
      </div>

  _onClick: (event) =>
    @props.onSelect?(@props.item, event)

    @props.onClick?(@props.item, event)
    if @_lastClickTime? and Date.now() - @_lastClickTime < 350
      @props.onDoubleClick?(@props.item, event)

    @_lastClickTime = Date.now()


class ListTabular extends React.Component
  @displayName = 'ListTabular'
  @propTypes =
    columns: React.PropTypes.arrayOf(React.PropTypes.object).isRequired
    dataView: React.PropTypes.object
    itemPropsProvider: React.PropTypes.func
    itemHeight: React.PropTypes.number
    onSelect: React.PropTypes.func
    onClick: React.PropTypes.func
    onDoubleClick: React.PropTypes.func

  constructor: (@props) ->
    if not @props.itemHeight
      throw new Error("ListTabular: You must provide an itemHeight - raising to avoid divide by zero errors.")

    @state =
      renderedRangeStart: -1
      renderedRangeEnd: -1
      scrollTop: 0
      scrollInProgress: false

  componentDidMount: =>
    @updateRangeState()

  componentWillUnmount: =>
    clearTimeout(@_scrollTimer) if @_scrollTimer

  componentDidUpdate: (prevProps, prevState) =>
    # If our view has been swapped out for an entirely different one,
    # reset our scroll position to the top.
    if prevProps.dataView isnt @props.dataView
      @refs.container.scrollTop = 0
    @updateRangeState()

  updateScrollState: =>
    window.requestAnimationFrame =>
      # Create an event that fires when we stop receiving scroll events.
      # There is no "scrollend" event, but we really need one.
      clearTimeout(@_scrollTimer) if @_scrollTimer
      @_scrollTimer = setTimeout(@onDoneReceivingScrollEvents, 100)

      # If we just started scrolling, scrollInProgress changes our CSS styles
      # and disables pointer events to our contents for rendering speed
      @setState({scrollInProgress: true}) unless @state.scrollInProgress

      # If we've shifted enough pixels from our previous scrollTop to require
      # new rows to be rendered, update our state!
      if Math.abs(@state.scrollTop - @refs.container.scrollTop) >= @props.itemHeight * RangeChunkSize
        @updateRangeState()

  onDoneReceivingScrollEvents: =>
    return unless React.findDOMNode(@refs.container)
    @setState({scrollInProgress: false})
    @updateRangeState()

  updateRangeState: =>
    scrollTop = @refs.container.scrollTop

    # Determine the exact range of rows we want onscreen
    rangeStart = Math.floor(scrollTop / @props.itemHeight)
    rangeEnd = rangeStart + window.innerHeight / @props.itemHeight

    # 1. Clip this range to the number of available items
    #
    # 2. Expand the range by more than RangeChunkSize so that
    #    the user can scroll through RangeChunkSize more items before
    #    another render is required.
    #
    rangeStart = Math.max(0, rangeStart - RangeChunkSize * 1.5)
    rangeEnd = Math.min(rangeEnd + RangeChunkSize * 1.5, @props.dataView.count())

    if @state.scrollInProgress
      # only extend the range while scrolling. If we remove the DOM node
      # the user started scrolling over, the deceleration stops.
      # https://code.google.com/p/chromium/issues/detail?id=312427
      if @state.renderedRangeStart != -1
        rangeStart = Math.min(@state.renderedRangeStart, rangeStart)
      if @state.renderedRangeEnd != -1
        rangeEnd = Math.max(@state.renderedRangeEnd, rangeEnd)

    # Final sanity check to prevent needless work
    return if rangeStart is @state.renderedRangeStart and
              rangeEnd is @state.renderedRangeEnd and
              scrollTop is @state.scrollTop

    @props.dataView.setRetainedRange
      start: rangeStart
      end: rangeEnd

    @setState
      scrollTop: scrollTop
      renderedRangeStart: rangeStart
      renderedRangeEnd: rangeEnd

  render: =>
    innerStyles =
      height: @props.dataView.count() * @props.itemHeight
      pointerEvents: if @state.scrollInProgress then 'none' else 'auto'

    <ScrollRegion ref="container" onScroll={@updateScrollState} tabIndex="-1" className="list-container list-tabular" scrollTooltipComponent={@props.scrollTooltipComponent} >
      {@_headers()}
      <div className="list-rows" style={innerStyles}>
        {@_rows()}
      </div>
    </ScrollRegion>

  _headers: =>
    return [] unless @props.displayHeaders

    headerColumns = @props.columns.map (column) ->
      <div className="list-header list-column"
           key={"header-#{column.name}"}
           style={flex: column.flex}>
        {column.name}
      </div>

    <div className="list-headers">
      {headerColumns}
    </div>

  _rows: =>
    rows = []

    for idx in [@state.renderedRangeStart..@state.renderedRangeEnd-1]
      item = @props.dataView.get(idx)
      continue unless item

      itemProps = {}
      if @props.itemPropsProvider
        itemProps = @props.itemPropsProvider(item)

      rows.push <ListTabularItem key={item.id ? idx}
                               item={item}
                               itemProps={itemProps}
                               metrics={top: idx * @props.itemHeight, height: @props.itemHeight}
                               columns={@props.columns}
                               onSelect={@props.onSelect}
                               onClick={@props.onClick}
                               onReorder={@props.onReorder}
                               onDoubleClick={@props.onDoubleClick} />
    rows

  # Public: Scroll to the DOM node provided.
  #
  scrollTo: (node) =>
    @refs.container.scrollTo(node)


ListTabular.Item = ListTabularItem
ListTabular.Column = ListColumn

module.exports = ListTabular

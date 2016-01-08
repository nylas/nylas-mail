_ = require 'underscore'
React = require 'react/addons'
ScrollRegion = require './scroll-region'
{Utils} = require 'nylas-exports'

class ListColumn
  constructor: ({@name, @resolver, @flex, @width}) ->

class ListTabularItem extends React.Component
  @displayName = 'ListTabularItem'
  @propTypes =
    metrics: React.PropTypes.object
    columns: React.PropTypes.arrayOf(React.PropTypes.object).isRequired
    item: React.PropTypes.object.isRequired
    itemProps: React.PropTypes.object
    onSelect: React.PropTypes.func
    onClick: React.PropTypes.func
    onDoubleClick: React.PropTypes.func

  # DO NOT DELETE unless you know what you're doing! This method cuts
  # React.Perf.wasted-time from ~300msec to 20msec by doing a deep
  # comparison of props before triggering a re-render.
  shouldComponentUpdate: (nextProps, nextState) =>
    if not Utils.isEqualReact(@props.item, nextProps.item) or @props.columns isnt nextProps.columns
      @_columnCache = null
      return true
    if not Utils.isEqualReact(_.omit(@props, 'item'), _.omit(nextProps, 'item'))
      return true
    false

  render: =>
    className = "list-item list-tabular-item #{@props.itemProps?.className}"
    props = _.omit(@props.itemProps ? {}, 'className')

    # It's expensive to compute the contents of columns (format timestamps, etc.)
    # We only do it if the item prop has changed.
    @_columnCache ?= @_columns()

    <div {...props} className={className} onClick={@_onClick} style={position:'absolute', top: @props.metrics.top, width:'100%', height:@props.metrics.height, overflow: 'hidden'}>
      {@_columnCache}
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

  componentDidMount: =>
    window.addEventListener('resize', @onWindowResize, true)
    @updateRangeState()

  componentWillUnmount: =>
    window.removeEventListener('resize', @onWindowResize, true)

  componentDidUpdate: (prevProps, prevState) =>
    # If our view has been swapped out for an entirely different one,
    # reset our scroll position to the top.
    if prevProps.dataView isnt @props.dataView
      @refs.container.scrollTop = 0

    unless @updateRangeStateFiring
      @updateRangeState()
    @updateRangeStateFiring = false

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
    rangeEnd = Math.min(rangeEnd + 2, @props.dataView.count() + 1)

    # Final sanity check to prevent needless work
    return if rangeStart is @state.renderedRangeStart and
              rangeEnd is @state.renderedRangeEnd

    @updateRangeStateFiring = true

    @props.dataView.setRetainedRange
      start: rangeStart
      end: rangeEnd

    @setState
      renderedRangeStart: rangeStart
      renderedRangeEnd: rangeEnd

  render: =>
    innerStyles =
      height: @props.dataView.count() * @props.itemHeight

    <ScrollRegion
      ref="container"
      onScroll={@onScroll}
      tabIndex="-1"
      className="list-container list-tabular"
      scrollTooltipComponent={@props.scrollTooltipComponent}>
      <div className="list-rows" style={innerStyles}>
        {@_rows()}
      </div>
    </ScrollRegion>

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

  scrollByPage: (direction) =>
    height = React.findDOMNode(@refs.container).clientHeight
    @refs.container.scrollTop += height * direction


ListTabular.Item = ListTabularItem
ListTabular.Column = ListColumn

module.exports = ListTabular

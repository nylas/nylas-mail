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
    @_unlisten?()

  componentWillReceiveProps: (nextProps) =>
    if nextProps.dataSource isnt @props.dataSource
      @setupDataSource(nextProps.dataSource)
      @setState(@buildStateForRange(dataSource: nextProps.dataSource))

  setupDataSource: (dataSource) =>
    @_unlisten?()
    @_unlisten = dataSource.listen =>
      @setState(@buildStateForRange())

  buildStateForRange: ({dataSource, start, end} = {}) =>
    start ?= @state.renderedRangeStart
    end ?= @state.renderedRangeEnd
    dataSource ?= @props.dataSource

    items = {}
    [start..end].forEach (idx) =>
      items[idx] = dataSource.get(idx)

    renderedRangeStart: start
    renderedRangeEnd: end
    count: dataSource.count()
    loaded: dataSource.loaded()
    empty: dataSource.empty()
    items: items

  componentDidUpdate: (prevProps, prevState) =>
    # If our view has been swapped out for an entirely different one,
    # reset our scroll position to the top.
    if prevProps.dataSource isnt @props.dataSource
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

    <div className={@props.className}>
      <ScrollRegion
        ref="container"
        onScroll={@onScroll}
        tabIndex="-1"
        className="list-container list-tabular"
        scrollTooltipComponent={@props.scrollTooltipComponent}>
        <div className="list-rows" style={innerStyles} {...otherProps}>
          {@_rows()}
        </div>
      </ScrollRegion>
      <Spinner visible={!@state.loaded and @state.empty} />
      {emptyElement}
    </div>

  _rows: =>
    [@state.renderedRangeStart..@state.renderedRangeEnd-1].map (idx) =>
      item = @state.items[idx]
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

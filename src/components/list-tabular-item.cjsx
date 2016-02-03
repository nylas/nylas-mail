_ = require 'underscore'
React = require 'react/addons'
{Utils} = require 'nylas-exports'

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


module.exports = ListTabularItem

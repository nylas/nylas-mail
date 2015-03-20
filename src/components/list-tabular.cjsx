_ = require 'underscore-plus'
React = require 'react'

class ListColumn
  constructor: ({@name, @resolver, @flex}) ->

ListTabularItem = React.createClass
  displayName: 'ListTabularItem'
  propTypes:
    item: React.PropTypes.object
    itemClassProvider: React.PropTypes.func
    displayHeaders: React.PropTypes.bool
    onSelect: React.PropTypes.func
    onClick: React.PropTypes.func
    onDoubleClick: React.PropTypes.func

  # DO NOT DELETE unless you know what you're doing! This method cuts
  # React.Perf.wasted-time from ~300msec to 20msec by doing a deep
  # comparison of props before triggering a re-render.
  shouldComponentUpdate: (nextProps, nextState) ->
    not _.isEqual(@props, nextProps)

  render: ->
    <div className={@_containerClasses()} onClick={@_onClick}>
      {@_columns()}
    </div>

  _columns: ->
    for column in (@props.columns ? [])
      <div key={column.name}
           displayName={column.name}
           style={flex: column.flex}
           className="list-column">
        {column.resolver(@props.item, @)}
      </div>

  _onClick: ->
    @props.onSelect?(@props.item)

    @props.onClick?(@props.item)
    if @_lastClickTime? and Date.now() - @_lastClickTime < 350
      @props.onDoubleClick?(@props.item)

    @_lastClickTime = Date.now()

  _containerClasses: ->
    classes = @props.itemClassProvider?(@props.item)
    classes =  '' unless _.isString(classes)
    classes += ' ' + React.addons.classSet
      'selected': @props.selected
      'list-item': true
      'list-tabular-item': true
    classes

module.exports =
ListTabular = React.createClass
  displayName: 'ListTabular'
  propTypes:
    columns: React.PropTypes.arrayOf(React.PropTypes.object)
    items: React.PropTypes.arrayOf(React.PropTypes.object)
    itemClassProvider: React.PropTypes.func
    selectedId: React.PropTypes.string
    onSelect: React.PropTypes.func
    onClick: React.PropTypes.func
    onDoubleClick: React.PropTypes.func

  render: ->
    <div tabIndex="-1" className="list-container list-tabular">
      {@_headers()}
      <div className="list-rows">
        {@_rows()}
      </div>
    </div>

  _headers: ->
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

  _rows: ->
    @props.items.map (item) =>
      <ListTabularItem key={item.id}
                       selected={item.id is @props.selectedId}
                       item={item}
                       itemClassProvider={@props.itemClassProvider}
                       columns={@props.columns}
                       onSelect={@props.onSelect}
                       onClick={@props.onClick}
                       onDoubleClick={@props.onDoubleClick} />


ListTabular.Item = ListTabularItem
ListTabular.Column = ListColumn

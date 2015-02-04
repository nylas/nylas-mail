_ = require 'underscore-plus'
React = require 'react/addons'

ThreadListItemMixin = require './thread-list-item-mixin.cjsx'

module.exports =
ThreadListTabularItem = React.createClass
  displayName: 'ThreadListTabularItem'
  mixins: [ThreadListItemMixin]

  render: ->
    <div className={@_containerClasses()}
         onClick={@_onClick}>
      {@_columns()}
    </div>

  # DO NOT DELETE unless you know what you're doing! This method cuts
  # React.Perf.wasted-time from ~300msec to 20msec by doing a deep
  # comparison of props before triggering a re-render.
  shouldComponentUpdate: (nextProps, nextState) ->
    not _.isEqual(@props, nextProps)

  _columns: ->
    for column in (@props.columns ? [])
      <div key={column.name}
           style={flex: "#{@props.columnFlex[column.name]}"}
           className="thread-list-column">
        {column.resolver(@props.thread, @)}
      </div>

  _containerClasses: ->
    React.addons.classSet
      'unread': @props.unread
      'selected': @props.selected
      'thread-list-item': true
      'thread-list-tabular-item': true

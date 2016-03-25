React = require 'react'
{Utils} = require 'nylas-exports'
ThreadListStore = require './thread-list-store'

class ThreadListScrollTooltip extends React.Component
  @displayName: 'ThreadListScrollTooltip'
  @propTypes:
    viewportCenter: React.PropTypes.number.isRequired
    totalHeight: React.PropTypes.number.isRequired

  componentWillMount: =>
    @setupForProps(@props)

  componentWillReceiveProps: (newProps) =>
    @setupForProps(newProps)

  shouldComponentUpdate: (newProps, newState) =>
    @state?.idx isnt newState.idx

  setupForProps: (props) ->
    idx = Math.floor(ThreadListStore.dataSource().count() / @props.totalHeight * @props.viewportCenter)
    @setState
      idx: idx
      item: ThreadListStore.dataSource().get(idx)

  render: ->
    if @state.item
      content = Utils.shortTimeString(@state.item.lastMessageReceivedTimestamp)
    else
      content = "Loading..."
    <div className="scroll-tooltip">
      {content}
    </div>

module.exports = ThreadListScrollTooltip

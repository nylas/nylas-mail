React = require 'react/addons'
moment = require 'moment'
{Utils} = require 'nylas-exports'

class ActivityBarLongPollItem extends React.Component
  @displayName: 'ActivityBarLongPollItem'

  constructor: (@props) ->
    @state = expanded: false

  shouldComponentUpdate: (nextProps, nextState) =>
    return not Utils.isEqualReact(nextProps, @props) or not Utils.isEqualReact(nextState, @state)

  render: =>
    if @state.expanded
      payload = JSON.stringify(@props.item)
    else
      payload = []

    itemId = @props.item.id
    itemVersion = @props.item.version || @props.item.attributes?.version
    itemId += " (version #{itemVersion})" if itemVersion

    timestamp = moment(@props.item.timestamp).format("h:mm:ss")

    <div className={"item"} onClick={ => @setState expanded: not @state?.expanded}>
      <div className="cursor">{@props.item.cursor}</div>
      {" #{timestamp}: #{@props.item.event} #{@props.item.object} #{itemId}"}
      <div className="payload" onClick={ (e) -> e.stopPropagation() }>
        {payload}
      </div>
    </div>



module.exports = ActivityBarLongPollItem

React = require 'react/addons'
moment = require 'moment'
{Utils} = require 'nylas-exports'

class DeveloperBarLongPollItem extends React.Component
  @displayName: 'DeveloperBarLongPollItem'

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

    classname = "item"
    right = @props.item.cursor

    if @props.item.ignoredBecause
      classname += " ignored"
      right = @props.item.ignoredBecause + " - " + right

    <div className={classname} onClick={ => @setState expanded: not @state?.expanded}>
      <div className="cursor">{right}</div>
      {" #{timestamp}: #{@props.item.event} #{@props.item.object} #{itemId}"}
      <div className="payload" onClick={ (e) -> e.stopPropagation() }>
        {payload}
      </div>
    </div>



module.exports = DeveloperBarLongPollItem

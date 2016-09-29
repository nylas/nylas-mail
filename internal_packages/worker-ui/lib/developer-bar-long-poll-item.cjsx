React = require 'react'
moment = require 'moment'
{DateUtils, Utils} = require 'nylas-exports'

class DeveloperBarLongPollItem extends React.Component
  @displayName: 'DeveloperBarLongPollItem'

  constructor: (@props) ->
    @state = expanded: false

  shouldComponentUpdate: (nextProps, nextState) =>
    return not Utils.isEqualReact(nextProps, @props) or not Utils.isEqualReact(nextState, @state)

  render: =>
    if @state.expanded
      payload = JSON.stringify(@props.item, null, 2)
    else
      payload = []

    itemId = @props.item.id
    itemVersion = @props.item.version || @props.item.attributes?.version
    itemId += " (version #{itemVersion})" if itemVersion

    timeFormat = DateUtils.getTimeFormat { seconds: true }
    timestamp = moment(@props.item.timestamp).format(timeFormat)

    classname = "item"
    right = @props.item.cursor

    if @props.ignoredBecause
      classname += " ignored"
      right = @props.ignoredBecause + " - " + right

    <div className={classname} onClick={ => @setState expanded: not @state?.expanded}>
      <div className="cursor">{right}</div>
      {" #{timestamp}: #{@props.item.event} #{@props.item.object} #{itemId}"}
      <div className="payload" onClick={ (e) -> e.stopPropagation() }>
        {payload}
      </div>
    </div>



module.exports = DeveloperBarLongPollItem

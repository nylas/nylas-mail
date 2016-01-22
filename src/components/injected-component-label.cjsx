React = require 'react'
_ = require 'underscore'

class InjectedComponentLabel extends React.Component
  @displayName: 'InjectedComponentLabel'

  render: ->
    matchingDescriptions = []
    for key, val of @props.matching
      val = val.id if key is 'location'
      val = _.pluck(val, 'id') if key is 'locations'
      matchingDescriptions.push("#{key}: #{val}")

    propDescriptions = []
    for key, val of @props
      continue if key is 'matching'
      propDescriptions.push("#{key}:<#{val?.constructor?.name ? typeof(val)}>")

    description  = " #{matchingDescriptions.join(', ')}"
    description += " (#{propDescriptions.join(', ')})" if propDescriptions.length > 0

    <span className="name">{description}</span>


module.exports = InjectedComponentLabel

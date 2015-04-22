moment = require "moment"
React = require 'react'

module.exports =
  timestamp: (time) ->
    diff = moment().diff(time, 'days', true)
    if diff <= 1
      format = "h:mm a"
    else if diff > 1 and diff <= 365
      format = "MMM D"
    else
      format = "MMM D YYYY"
    moment(time).format(format)

  subject: (subj) ->
    if (subj ? "").trim().length is 0
      return <span className="no-subject">(No Subject)</span>
    else
      return subj

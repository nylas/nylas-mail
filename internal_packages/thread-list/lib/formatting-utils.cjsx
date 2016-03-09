{Utils} = require 'nylas-exports'
React = require 'react'

module.exports =
  timestamp: (time) ->
    Utils.shortTimeString(time)

  subject: (subj) ->
    if (subj ? "").trim().length is 0
      return <span className="no-subject">(No Subject)</span>
    else
      return subj


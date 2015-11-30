React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class PreferencesMailRules extends React.Component
  @displayName: 'PreferencesMailRules'

  render: =>
    <div className="container-mail-rules">
      {@props.accountId}
    </div>

module.exports = PreferencesMailRules

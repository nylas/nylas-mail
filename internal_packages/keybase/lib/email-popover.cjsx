{React, Actions} = require 'nylas-exports'
{ParticipantsTextField} = require 'nylas-component-kit'
Identity = require './identity'
_ = require 'underscore'

module.exports =
class EmailPopover extends React.Component
  constructor: ->
    @state = {to: [], cc: [], bcc: []}

  @propTypes:
    profile: React.PropTypes.instanceOf(Identity).isRequired

  render: ->
    participants = @state

    <div className="keybase-import-popover">
      <ParticipantsTextField
        field="to"
        className="keybase-participant-field"
        participants={ participants }
        change={ @_onRecipientFieldChange } />
      <button className="btn btn-toolbar" onClick={ @_onDone }>Associate Emails with Key</button>
    </div>

  _onRecipientFieldChange: (contacts) =>
    @setState(contacts)

  _onDone: =>
    @props.onPopoverDone(_.pluck(@state.to, 'email'), @props.profile)
    Actions.closePopover()

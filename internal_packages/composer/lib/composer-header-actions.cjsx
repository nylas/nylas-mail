React = require 'react'
Fields = require './fields'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

module.exports =
class ComposerHeaderActions extends React.Component
  @displayName: 'ComposerHeaderActions'

  @propTypes:
    draftClientId: React.PropTypes.string.isRequired
    focusedField: React.PropTypes.string
    enabledFields: React.PropTypes.array.isRequired
    onAdjustEnabledFields: React.PropTypes.func.isRequired

  render: =>
    items = []

    if @props.focusedField in Fields.ParticipantFields
      if Fields.Cc not in @props.enabledFields
        items.push(
          <span className="action show-cc" key="cc"
                onClick={ => @props.onAdjustEnabledFields(show: [Fields.Cc]) }>Cc</span>
        )

      if Fields.Bcc not in @props.enabledFields
        items.push(
          <span className="action show-bcc" key="bcc"
                onClick={ => @props.onAdjustEnabledFields(show: [Fields.Bcc]) }>Bcc</span>
        )

      if Fields.Subject not in @props.enabledFields
        items.push(
          <span className="action show-subject" key="subject"
                onClick={ => @props.onAdjustEnabledFields(show: [Fields.Subject]) }>Subject</span>
        )

    unless NylasEnv.isComposerWindow()
      items.push(
        <span className="action show-popout"  key="popout"
              title="Popout composer…"
              style={paddingLeft: "1.5em"}
              onClick={@_onPopoutComposer}>
          <RetinaImg name="composer-popout.png"
            mode={RetinaImg.Mode.ContentIsMask}
            style={{position: "relative", top: "-2px"}}/>
        </span>
      )

    <div className="composer-header-actions">
      {items}
    </div>

  _onPopoutComposer: =>
    Actions.composePopoutDraft(@props.draftClientId)

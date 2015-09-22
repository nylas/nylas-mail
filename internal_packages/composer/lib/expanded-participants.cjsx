_ = require 'underscore'
React = require 'react'
AccountContactField = require './account-contact-field'
ParticipantsTextField = require './participants-text-field'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

Fields = require './fields'

class ExpandedParticipants extends React.Component
  @displayName: "ExpandedParticipants"

  @propTypes:
    # Arrays of Contact objects.
    to: React.PropTypes.array
    cc: React.PropTypes.array
    bcc: React.PropTypes.array
    from: React.PropTypes.array

    # Either "fullwindow" or "inline"
    mode: React.PropTypes.string

    # The field that should be focused
    focusedField: React.PropTypes.string

    # An enum array of visible fields. Can be any constant in the `Fields`
    # dict.  We are passed these as props instead of holding it as state
    # since this component is frequently unmounted and re-mounted every
    # time it is displayed
    enabledFields: React.PropTypes.array

    # Callback for when a user changes which fields should be visible
    onChangeEnabledFields: React.PropTypes.func

    # Callback for the participants change
    onChangeParticipants: React.PropTypes.func

  @defaultProps:
    to: []
    cc: []
    bcc: []
    from: []
    enabledFields: []

  constructor: (@props={}) ->

  componentDidMount: =>
    @_applyFocusedField()

  componentDidUpdate: ->
    @_applyFocusedField()

  render: ->
    <div className="expanded-participants" 
         ref="participantWrap">
      {@_renderFields()}
    </div>

  _applyFocusedField: ->
    if @props.focusedField
      return unless @refs[@props.focusedField]
      if @refs[@props.focusedField].focus
        @refs[@props.focusedField].focus()
      else
        React.findDOMNode(@refs[@props.focusedField]).focus()

  _renderFields: =>
    # Note: We need to physically add and remove these elements, not just hide them.
    # If they're hidden, shift-tab between fields breaks.
    fields = []
    fields.push(
      <div key="to">
        <div className="composer-participant-actions">
          {if Fields.Cc not in @props.enabledFields
            <span className="header-action show-cc"
                  onClick={@_showAndFocusCc}>Cc</span>
          }

          { if Fields.Bcc not in @props.enabledFields
            <span className="header-action show-bcc"
                  onClick={@_showAndFocusBcc}>Bcc</span>
          }

          { if Fields.Subject not in @props.enabledFields
            <span className="header-action show-subject"
                  onClick={@_showAndFocusSubject}>Subject</span>
          }

          { if @props.mode is "inline"
            <span className="header-action show-popout"
                  data-tooltip="Popout composer"
                  style={paddingLeft: "1.5em"}
                  onClick={@props.onPopoutComposer}>
              <RetinaImg name="composer-popout.png"
                mode={RetinaImg.Mode.ContentIsMask}
                style={{position: "relative", top: "-2px"}}/>
            </span>
          }
        </div>
        <ParticipantsTextField
          ref={Fields.To}
          field='to'
          change={@props.onChangeParticipants}
          className="composer-participant-field to-field"
          participants={to: @props['to'], cc: @props['cc'], bcc: @props['bcc']} />
      </div>
    )

    if Fields.Cc in @props.enabledFields
      fields.push(
        <ParticipantsTextField
          ref={Fields.Cc}
          key="cc"
          field='cc'
          change={@props.onChangeParticipants}
          onEmptied={@_onEmptyCc}
          className="composer-participant-field cc-field"
          participants={to: @props['to'], cc: @props['cc'], bcc: @props['bcc']} />
      )

    if Fields.Bcc in @props.enabledFields
      fields.push(
        <ParticipantsTextField
          ref={Fields.Bcc}
          key="bcc"
          field='bcc'
          change={@props.onChangeParticipants}
          onEmptied={@_onEmptyBcc}
          className="composer-participant-field bcc-field"
          participants={to: @props['to'], cc: @props['cc'], bcc: @props['bcc']} />
      )

    if Fields.From in @props.enabledFields
      fields.push(
        <AccountContactField
          key="from"
          ref={Fields.From}
          onChange={ (me) => @props.onChangeParticipants(from: [me]) }
          value={@props.from?[0]} />
      )

    fields

  _showAndFocusBcc: =>
    @props.onChangeEnabledFields
      show: [Fields.Bcc]
      focus: Fields.Bcc

  _showAndFocusCc: =>
    @props.onChangeEnabledFields
      show: [Fields.Cc]
      focus: Fields.Cc

  _showAndFocusSubject: =>
    @props.onChangeEnabledFields
      show: [Fields.Subject]
      focus: Fields.Subject

  _onEmptyCc: =>
    @props.onChangeEnabledFields
      hide: [Fields.Cc]
      focus: Fields.To

  _onEmptyBcc: =>
    if Fields.Cc in @props.enabledFields
      focus = Fields.Cc
    else
      focus = Fields.To
    @props.onChangeEnabledFields
      hide: [Fields.Bcc]
      focus: focus

module.exports = ExpandedParticipants
